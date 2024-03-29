require 'delegate'
require 'optparse'
require 'fileutils'
require 'erb'

module Rails
  module Generator
    module Commands
      # Here's a convenient way to get a handle on generator commands.
      # Command.instance('destroy', my_generator) instantiates a Destroy
      # delegate of my_generator ready to do your dirty work.
      def self.instance(command, generator)
        const_get(command.to_s.camelize).new(generator)
      end

      # Even more convenient access to commands.  Include Commands in
      # the generator Base class to get a nice #command instance method
      # which returns a delegate for the requested command.
      def self.append_features(base)
        base.send(:define_method, :command) do |command|
          Commands.instance(command, self)
        end
      end


      # Generator commands delegate Rails::Generator::Base and implement
      # a standard set of actions.  Their behavior is defined by the way
      # they respond to these actions: Create brings life; Destroy brings
      # death; List passively observes.
      #
      # Commands are invoked by replaying (or rewinding) the generator's
      # manifest of actions.  See Rails::Generator::Manifest and
      # Rails::Generator::Base#manifest method that generator subclasses
      # are required to override.
      #
      # Commands allows generators to "plug in" invocation behavior, which
      # corresponds to the GoF Strategy pattern.
      class Base < DelegateClass(Rails::Generator::Base)
        # Replay action manifest.  RewindBase subclass rewinds manifest.
        def invoke!
          manifest.replay(self)
        end

        def dependency(generator_name, args, runtime_options = {})
          logger.dependency(generator_name) do
            self.class.new(instance(generator_name, args, full_options(runtime_options))).invoke!
          end
        end

        # Does nothing for all commands except Create.
        def class_collisions(*class_names)
        end

        # Does nothing for all commands except Create.
        def readme(*args)
        end

        protected
          def migration_directory(relative_path)
            directory(@migration_directory = relative_path)
          end

          def existing_migrations(file_name)
            Dir.glob("#{@migration_directory}/[0-9]*_#{file_name}.rb")
          end

          def migration_exists?(file_name)
            not existing_migrations(file_name).empty?
          end

          def current_migration_number
            Dir.glob("#{@migration_directory}/[0-9]*.rb").inject(0) do |max, file_path|
              n = File.basename(file_path).split('_', 2).first.to_i
              if n > max then n else max end
            end
          end

          def next_migration_number
            current_migration_number + 1
          end

          def next_migration_string(padding = 3)
            "%.#{padding}d" % next_migration_number
          end

        private
          # Ask the user interactively whether to force collision.
          def force_file_collision?(destination)
            $stdout.print "overwrite #{destination}? [Ynaq] "
            case $stdin.gets
              when /a/i
                $stdout.puts "forcing #{spec.name}"
                options[:collision] = :force
              when /q/i
                $stdout.puts "aborting #{spec.name}"
                raise SystemExit
              when /n/i then :skip
              else :force
            end
          rescue
            retry
          end

          def render_template_part(template_options)
            # Getting Sandbox to evaluate part template in it
            part_binding = template_options[:sandbox].call.sandbox_binding
            part_rel_path = template_options[:insert]
            part_path = source_path(part_rel_path)

            # Render inner template within Sandbox binding
            rendered_part = ERB.new(File.readlines(part_path).join, nil, '-').result(part_binding)
            begin_mark = template_part_mark(template_options[:begin_mark], template_options[:mark_id])
            end_mark = template_part_mark(template_options[:end_mark], template_options[:mark_id])
            begin_mark + rendered_part + end_mark
          end

          def template_part_mark(name, id)
            "<!--[#{name}:#{id}]-->\n"
          end
      end

      # Base class for commands which handle generator actions in reverse, such as Destroy.
      class RewindBase < Base
        # Rewind action manifest.
        def invoke!
          manifest.rewind(self)
        end
      end


      # Create is the premier generator command.  It copies files, creates
      # directories, renders templates, and more.
      class Create < Base

        # Check whether the given class names are already taken by
        # Ruby or Rails.  In the future, expand to check other namespaces
        # such as the rest of the user's app.
        def class_collisions(*class_names)
          class_names.flatten.each do |class_name|
            # Convert to string to allow symbol arguments.
            class_name = class_name.to_s

            # Skip empty strings.
            next if class_name.strip.empty?

            # Split the class from its module nesting.
            nesting = class_name.split('::')
            name = nesting.pop

            # Extract the last Module in the nesting.
            last = nesting.inject(Object) { |last, nest|
              break unless last.const_defined?(nest)
              last.const_get(nest)
            }

            # If the last Module exists, check whether the given
            # class exists and raise a collision if so.
            if last and last.const_defined?(name.camelize)
              raise_class_collision(class_name)
            end
          end
        end

        # Copy a file from source to destination with collision checking.
        #
        # The file_options hash accepts :chmod and :shebang options.
        # :chmod sets the permissions of the destination file:
        #   file 'config/empty.log', 'log/test.log', :chmod => 0664
        # :shebang sets the #!/usr/bin/ruby line for scripts
        #   file 'bin/generate.rb', 'script/generate', :chmod => 0755, :shebang => '/usr/bin/env ruby'
        #
        # Collisions are handled by checking whether the destination file
        # exists and either skipping the file, forcing overwrite, or asking
        # the user what to do.
        def file(relative_source, relative_destination, file_options = {}, &block)
          # Determine full paths for source and destination files.
          source              = source_path(relative_source)
          destination         = destination_path(relative_destination)
          destination_exists  = File.exist?(destination)

          # If source and destination are identical then we're done.
          if destination_exists and identical?(source, destination, &block)
            return logger.identical(relative_destination) 
          end

          # Check for and resolve file collisions.
          if destination_exists

            # Make a choice whether to overwrite the file.  :force and
            # :skip already have their mind made up, but give :ask a shot.
            choice = case options[:collision].to_sym #|| :ask
              when :ask   then force_file_collision?(relative_destination)
              when :force then :force
              when :skip  then :skip
              else raise "Invalid collision option: #{options[:collision].inspect}"
            end

            # Take action based on our choice.  Bail out if we chose to
            # skip the file; otherwise, log our transgression and continue.
            case choice
              when :force then logger.force(relative_destination)
              when :skip  then return(logger.skip(relative_destination))
              else raise "Invalid collision choice: #{choice}.inspect"
            end

          # File doesn't exist so log its unbesmirched creation.
          else
            logger.create relative_destination
          end

          # If we're pretending, back off now.
          return if options[:pretend]

          # Write destination file with optional shebang.  Yield for content
          # if block given so templaters may render the source file.  If a
          # shebang is requested, replace the existing shebang or insert a
          # new one.
          File.open(destination, 'wb') do |df|
            File.open(source, 'rb') do |sf|
              if block_given?
                df.write(yield(sf))
              else
                if file_options[:shebang]
                  df.puts("#!#{file_options[:shebang]}")
                  if line = sf.gets
                    df.puts(line) if line !~ /^#!/
                  end
                end
                df.write(sf.read)
              end
            end
          end

          # Optionally change permissions.
          if file_options[:chmod]
            FileUtils.chmod(file_options[:chmod], destination)
          end
          
          # Optionally add file to subversion
          system("svn add #{destination}") if options[:svn]
        end

        # Checks if the source and the destination file are identical. If
        # passed a block then the source file is a template that needs to first
        # be evaluated before being compared to the destination.
        def identical?(source, destination, &block)
          return false if File.directory? destination
          source      = block_given? ? File.open(source) {|sf| yield(sf)} : IO.read(source)
          destination = IO.read(destination)
          source == destination
        end

        # Generate a file for a Rails application using an ERuby template.
        # Looks up and evalutes a template by name and writes the result.
        #
        # The ERB template uses explicit trim mode to best control the
        # proliferation of whitespace in generated code.  <%- trims leading
        # whitespace; -%> trims trailing whitespace including one newline.
        #
        # A hash of template options may be passed as the last argument.
        # The options accepted by the file are accepted as well as :assigns,
        # a hash of variable bindings.  Example:
        #   template 'foo', 'bar', :assigns => { :action => 'view' }
        #
        # Template is implemented in terms of file.  It calls file with a
        # block which takes a file handle and returns its rendered contents.
        def template(relative_source, relative_destination, template_options = {})
          file(relative_source, relative_destination, template_options) do |file|
            # Evaluate any assignments in a temporary, throwaway binding.
            vars = template_options[:assigns] || {}
            b = Kernel.binding
            vars.each { |k,v| eval "#{k} = vars[:#{k}] || vars['#{k}']", b }

            # Render the source file with the temporary binding.
            ERB.new(file.read, nil, '-').result(b)
          end
        end

        def complex_template(relative_source, relative_destination, template_options = {})
          options = template_options.dup
          options[:assigns] ||= {}
          options[:assigns]['template_for_inclusion'] = render_template_part(template_options)
          template(relative_source, relative_destination, options)
        end

        # Create a directory including any missing parent directories.
        # Always directories which exist.
        def directory(relative_path)
          path = destination_path(relative_path)
          if File.exist?(path)
            logger.exists relative_path
          else
            logger.create relative_path
            FileUtils.mkdir_p(path) unless options[:pretend]
            
            # Optionally add file to subversion
            system("svn add #{path}") if options[:svn]
          end
        end

        # Display a README.
        def readme(*relative_sources)
          relative_sources.flatten.each do |relative_source|
            logger.readme relative_source
            puts File.read(source_path(relative_source)) unless options[:pretend]
          end
        end

        # When creating a migration, it knows to find the first available file in db/migrate and use the migration.rb template.
        def migration_template(relative_source, relative_destination, template_options = {})
          migration_directory relative_destination
          raise "Another migration is already named #{file_name}: #{existing_migrations(file_name).first}" if migration_exists?(file_name)
          template(relative_source, "#{relative_destination}/#{next_migration_string}_#{file_name}.rb", template_options)
        end

        private
          # Raise a usage error with an informative WordNet suggestion.
          # Thanks to Florian Gross (flgr).
          def raise_class_collision(class_name)
            message = <<end_message
  The name '#{class_name}' is reserved by Ruby on Rails.
  Please choose an alternative and run this generator again.
end_message
            if suggest = find_synonyms(class_name)
              message << "\n  Suggestions:  \n\n"
              message << suggest.join("\n")
            end
            raise UsageError, message
          end

          SYNONYM_LOOKUP_URI = "http://wordnet.princeton.edu/cgi-bin/webwn2.0?stage=2&word=%s&posnumber=1&searchtypenumber=2&senses=&showglosses=1"

          # Look up synonyms on WordNet.  Thanks to Florian Gross (flgr).
          def find_synonyms(word)
            require 'open-uri'
            require 'timeout'
            timeout(5) do
              open(SYNONYM_LOOKUP_URI % word) do |stream|
                data = stream.read.gsub("&nbsp;", " ").gsub("<BR>", "")
                data.scan(/^Sense \d+\n.+?\n\n/m)
              end
            end
          rescue Exception
            return nil
          end
      end


      # Undo the actions performed by a generator.  Rewind the action
      # manifest and attempt to completely erase the results of each action.
      class Destroy < RewindBase
        # Remove a file if it exists and is a file.
        def file(relative_source, relative_destination, file_options = {})
          destination = destination_path(relative_destination)
          if File.exist?(destination)
            logger.rm relative_destination
            unless options[:pretend]
              if options[:svn]
                # If the file has been marked to be added
                # but has not yet been checked in, revert and delete
                if options[:svn][relative_destination]
                  system("svn revert #{destination}")
                  FileUtils.rm(destination)
                else
                # If the directory is not in the status list, it
                # has no modifications so we can simply remove it
                  system("svn rm #{destination}")
                end  
              else
                FileUtils.rm(destination)
              end
            end
          else
            logger.missing relative_destination
            return
          end
        end

        # Templates are deleted just like files and the actions take the
        # same parameters, so simply alias the file method.
        alias_method :template, :file

        # Remove each directory in the given path from right to left.
        # Remove each subdirectory if it exists and is a directory.
        def directory(relative_path)
          parts = relative_path.split('/')
          until parts.empty?
            partial = File.join(parts)
            path = destination_path(partial)
            if File.exist?(path)
              if Dir[File.join(path, '*')].empty?
                logger.rmdir partial
                unless options[:pretend]
                  if options[:svn]
                    # If the directory has been marked to be added
                    # but has not yet been checked in, revert and delete
                    if options[:svn][relative_path]
                      system("svn revert #{path}")
                      FileUtils.rmdir(path)
                    else
                    # If the directory is not in the status list, it
                    # has no modifications so we can simply remove it
                      system("svn rm #{path}")
                    end
                  else
                    FileUtils.rmdir(path)
                  end
                end
              else
                logger.notempty partial
              end
            else
              logger.missing partial
            end
            parts.pop
          end
        end

        def complex_template(*args)
          # nothing should be done here
        end

        # When deleting a migration, it knows to delete every file named "[0-9]*_#{file_name}".
        def migration_template(relative_source, relative_destination, template_options = {})
          migration_directory relative_destination
          raise "There is no migration named #{file_name}" unless migration_exists?(file_name)
          existing_migrations(file_name).each do |file_path|
            file(relative_source, file_path, template_options)
          end
        end
      end


      # List a generator's action manifest.
      class List < Base
        def dependency(generator_name, args, options = {})
          logger.dependency "#{generator_name}(#{args.join(', ')}, #{options.inspect})"
        end

        def class_collisions(*class_names)
          logger.class_collisions class_names.join(', ')
        end

        def file(relative_source, relative_destination, options = {})
          logger.file relative_destination
        end

        def template(relative_source, relative_destination, options = {})
          logger.template relative_destination
        end

        def complex_template(relative_source, relative_destination, options = {})
          logger.template "#{options[:insert]} inside #{relative_destination}"
        end

        def directory(relative_path)
          logger.directory "#{destination_path(relative_path)}/"
        end

        def readme(*args)
          logger.readme args.join(', ')
        end
        
        def migration_template(relative_source, relative_destination, options = {})
          migration_directory relative_destination
          logger.migration_template file_name
        end
      end

      # Update generator's action manifest.
      class Update < Create
        def file(relative_source, relative_destination, options = {})
          # logger.file relative_destination
        end

        def template(relative_source, relative_destination, options = {})
          # logger.template relative_destination
        end

        def complex_template(relative_source, relative_destination, template_options = {})

           begin
             dest_file = destination_path(relative_destination)
             source_to_update = File.readlines(dest_file).join
           rescue Errno::ENOENT
             logger.missing relative_destination
             return
           end

           logger.refreshing "#{template_options[:insert].gsub(/\.rhtml/,'')} inside #{relative_destination}"

           begin_mark = Regexp.quote(template_part_mark(template_options[:begin_mark], template_options[:mark_id]))
           end_mark = Regexp.quote(template_part_mark(template_options[:end_mark], template_options[:mark_id]))

           # Refreshing inner part of the template with freshly rendered part.
           rendered_part = render_template_part(template_options)
           source_to_update.gsub!(/#{begin_mark}.*?#{end_mark}/m, rendered_part)

           File.open(dest_file, 'w') { |file| file.write(source_to_update) }
        end

        def directory(relative_path)
          # logger.directory "#{destination_path(relative_path)}/"
        end
      end

    end
  end
end
