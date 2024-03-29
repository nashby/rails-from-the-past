require 'optparse'

module Rails
  module Generator
    module Options
      def self.append_features(base)
        super
        base.extend(ClassMethods)
        class << base
          if respond_to?(:inherited)
            alias_method :inherited_without_options, :inherited
          end
          alias_method :inherited, :inherited_with_options
        end
      end

      module ClassMethods
        def inherited_with_options(sub)
          inherited_without_options(sub) if respond_to?(:inherited_without_options)
          sub.extend(Rails::Generator::Options::ClassMethods)
        end

        def mandatory_options(options = nil)
          if options
            write_inheritable_attribute(:mandatory_options, options)
          else
            read_inheritable_attribute(:mandatory_options) or write_inheritable_attribute(:mandatory_options, {})
          end
        end

        def default_options(options = nil)
          if options
            write_inheritable_attribute(:default_options, options)
          else
            read_inheritable_attribute(:default_options) or write_inheritable_attribute(:default_options, {})
          end
        end

        # Merge together our class options.  In increasing precedence:
        #   default_options   (class default options)
        #   runtime_options   (provided as argument)
        #   mandatory_options (class mandatory options)
        def full_options(runtime_options = {})
          default_options.merge(runtime_options).merge(mandatory_options)
        end

      end

      # Each instance has an options hash that's populated by #parse.
      def options
        @options ||= {}
      end
      attr_writer :options

      protected
        # Convenient access to class mandatory options.
        def mandatory_options
          self.class.mandatory_options
        end

        # Convenient access to class default options.
        def default_options
          self.class.default_options
        end

        # Merge together our instance options.  In increasing precedence:
        #   default_options   (class default options)
        #   options           (instance options)
        #   runtime_options   (provided as argument)
        #   mandatory_options (class mandatory options)
        def full_options(runtime_options = {})
          self.class.full_options(options.merge(runtime_options))
        end

        # Parse arguments into the options hash.  Classes may customize
        # parsing behavior by overriding these methods:
        #   #banner                 Usage: ./script/generate [options]
        #   #add_options!           Options:
        #                             some options..
        #   #add_general_options!   General Options:
        #                             general options..
        def parse!(args, runtime_options = {})
          self.options = {}

          @option_parser = OptionParser.new do |opt|
            opt.banner = banner
            add_options!(opt)
            add_general_options!(opt)
            opt.parse!(args)
          end

          return args
        ensure
          self.options = full_options(runtime_options)
        end

        # Raise a usage error.  Override usage_message to provide a blurb
        # after the option parser summary.
        def usage
          raise UsageError, "#{@option_parser}\n#{usage_message}"
        end

        def usage_message
          ''
        end

        # Override with your own usage banner.
        def banner
          "Usage: #{$0} [options]"
        end

        # Override to add your options to the parser:
        #   def add_options!(opt)
        #     opt.on('-v', '--verbose') { |value| options[:verbose] = value }
        #   end
        def add_options!(opt)
        end

        # Adds general options like -h and --quiet.  Usually don't override.
        def add_general_options!(opt)
          opt.separator ''
          opt.separator 'General Options:'

          opt.on('-p', '--pretend', 'Run but do not make any changes.') { |o| options[:pretend] = o }
          opt.on('-f', '--force', 'Overwrite files that already exist.') { options[:collision] = :force }
          opt.on('-s', '--skip', 'Skip files that already exist.') { options[:collision] = :skip }
          opt.on('-q', '--quiet', 'Suppress normal output.') { |o| options[:quiet] = o }
          opt.on('-t', '--backtrace', 'Debugging: show backtrace on errors.') { |o| options[:backtrace] = o }
          opt.on('-h', '--help', 'Show this help message.') { |o| options[:help] = o  }
          opt.on('-c', '--svn', 'Modify files with subversion. (Note: svn must be in path)') do
            options[:svn] = `svn status`.inject({}) do |opt, e|
              opt[e.chomp[7..-1]] = true
              opt
            end
          end
        end

    end
  end
end
