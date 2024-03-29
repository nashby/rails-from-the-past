require 'erb'

module ActionView #:nodoc:

  class ActionViewError < StandardError #:nodoc:
  end

  # Action View templates can be written in two ways. If the template file has a +.rhtml+ extension then it uses a mixture of ERb 
  # (included in Ruby) and HTML. If the template file has a +.rxml+ extension then Jim Weirich's Builder::XmlMarkup library is used.  
  # 
  # = ERb
  # 
  # You trigger ERb by using embeddings such as <% %> and <%= %>. The difference is whether you want output or not. Consider the 
  # following loop for names:
  #
  #   <b>Names of all the people</b>
  #   <% for person in @people %>
  #     Name: <%= person.name %><br/>
  #   <% end %>
  #
  # The loop is setup in regular embedding tags (<% %>) and the name is written using the output embedding tag (<%= %>). Note that this
  # is not just a usage suggestion. Regular output functions like print or puts won't work with ERb templates. So this would be wrong:
  #
  #   Hi, Mr. <% puts "Frodo" %>
  #
  # (If you absolutely must write from within a function, you can use the TextHelper#concat)
  #
  # == Using sub templates
  #
  # Using sub templates allows you to sidestep tedious replication and extract common display structures in shared templates. The
  # classic example is the use of a header and footer (even though the Action Pack-way would be to use Layouts):
  #
  #   <%= render "shared/header" %>
  #   Something really specific and terrific
  #   <%= render "shared/footer" %>
  #
  # As you see, we use the output embeddings for the render methods. The render call itself will just return a string holding the
  # result of the rendering. The output embedding writes it to the current template.
  #
  # But you don't have to restrict yourself to static includes. Templates can share variables amongst themselves by using instance
  # variables defined using the regular embedding tags. Like this:
  #
  #   <% @page_title = "A Wonderful Hello" %>
  #   <%= render "shared/header" %>
  #
  # Now the header can pick up on the @page_title variable and use it for outputting a title tag:
  #
  #   <title><%= @page_title %></title>
  #
  # == Passing local variables to sub templates
  # 
  # You can pass local variables to sub templates by using a hash with the variable names as keys and the objects as values:
  #
  #   <%= render "shared/header", { "headline" => "Welcome", "person" => person } %>
  #
  # These can now be accessed in shared/header with:
  #
  #   Headline: <%= headline %>
  #   First name: <%= person.first_name %>
  #
  # == Template caching
  #
  # By default, Rails will compile each template to a method in order to render it. When you alter a template, Rails will
  # check the file's modification time and recompile it.
  #
  # == Builder
  #
  # Builder templates are a more programmatic alternative to ERb. They are especially useful for generating XML content. An +XmlMarkup+ object 
  # named +xml+ is automatically made available to templates with a +.rxml+ extension. 
  #
  # Here are some basic examples:
  #
  #   xml.em("emphasized")                              # => <em>emphasized</em>
  #   xml.em { xml.b("emp & bold") }                    # => <em><b>emph &amp; bold</b></em>
  #   xml.a("A Link", "href"=>"http://onestepback.org") # => <a href="http://onestepback.org">A Link</a>
  #   xm.target("name"=>"compile", "option"=>"fast")    # => <target option="fast" name="compile"\>
  #                                                     # NOTE: order of attributes is not specified.
  # 
  # Any method with a block will be treated as an XML markup tag with nested markup in the block. For example, the following:
  #
  #   xml.div {
  #     xml.h1(@person.name)
  #     xml.p(@person.bio)
  #   }
  #
  # would produce something like:
  #
  #   <div>
  #     <h1>David Heinemeier Hansson</h1>
  #     <p>A product of Danish Design during the Winter of '79...</p>
  #   </div>
  #
  # A full-length RSS example actually used on Basecamp:
  #
  #   xml.rss("version" => "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
  #     xml.channel do
  #       xml.title(@feed_title)
  #       xml.link(@url)
  #       xml.description "Basecamp: Recent items"
  #       xml.language "en-us"
  #       xml.ttl "40"
  # 
  #       for item in @recent_items
  #         xml.item do
  #           xml.title(item_title(item))
  #           xml.description(item_description(item)) if item_description(item)
  #           xml.pubDate(item_pubDate(item))
  #           xml.guid(@person.firm.account.url + @recent_items.url(item))
  #           xml.link(@person.firm.account.url + @recent_items.url(item))
  #       
  #           xml.tag!("dc:creator", item.author_name) if item_has_creator?(item)
  #         end
  #       end
  #     end
  #   end
  #
  # More builder documentation can be found at http://builder.rubyforge.org.
  class Base
    include ERB::Util

    attr_reader   :first_render
    attr_accessor :base_path, :assigns, :template_extension
    attr_accessor :controller

    attr_reader :logger, :params, :request, :response, :session, :headers, :flash

    # Specify trim mode for the ERB compiler. Defaults to '-'.
    # See ERB documentation for suitable values.
    @@erb_trim_mode = '-'
    cattr_accessor :erb_trim_mode

    # Specify whether file modification times should be checked to see if a template needs recompilation
    @@cache_template_loading = false
    cattr_accessor :cache_template_loading

    # Specify whether local_assigns should be able to use string keys.
    # Defaults to +true+. String keys are deprecated and will be removed
    # shortly.
    @@local_assigns_support_string_keys = true
    cattr_accessor :local_assigns_support_string_keys

    @@template_handlers = {}
 
    module CompiledTemplates #:nodoc:
      # holds compiled template code
    end
    include CompiledTemplates

    # maps inline templates to their method names 
    @@method_names = {}
    # map method names to their compile time
    @@compile_time = {}
    # map method names to the names passed in local assigns so far
    @@template_args = {}
    # count the number of inline templates
    @@inline_template_count = 0    

    class ObjectWrapper < Struct.new(:value) #:nodoc:
    end

    def self.load_helpers(helper_dir)#:nodoc:
      Dir.foreach(helper_dir) do |helper_file| 
        next unless helper_file =~ /^([a-z][a-z_]*_helper).rb$/
        require File.join(helper_dir, $1)
        helper_module_name = $1.camelize
        class_eval("include ActionView::Helpers::#{helper_module_name}") if Helpers.const_defined?(helper_module_name)
      end
    end

    # Register a class that knows how to handle template files with the given
    # extension. This can be used to implement new template types.
    # The constructor for the class must take the ActiveView::Base instance
    # as a parameter, and the class must implement a #render method that
    # takes the contents of the template to render as well as the Hash of
    # local assigns available to the template. The #render method ought to
    # return the rendered template as a string.
    def self.register_template_handler(extension, klass)
      @@template_handlers[extension] = klass
    end

    def initialize(base_path = nil, assigns_for_first_render = {}, controller = nil)#:nodoc:
      @base_path, @assigns = base_path, assigns_for_first_render
      @assigns_added = nil
      @controller = controller
      @logger = controller && controller.logger 
    end

    # Renders the template present at <tt>template_path</tt>. If <tt>use_full_path</tt> is set to true, 
    # it's relative to the template_root, otherwise it's absolute. The hash in <tt>local_assigns</tt> 
    # is made available as local variables.
    def render_file(template_path, use_full_path = true, local_assigns = {})
      @first_render      = template_path if @first_render.nil?

      if use_full_path
        template_extension = pick_template_extension(template_path)
        template_file_name = full_template_path(template_path, template_extension)
      else
        template_file_name = template_path
        template_extension = template_path.split('.').last
      end

      template_source = nil # Don't read the source until we know that it is required

      begin
        render_template(template_extension, template_source, template_file_name, local_assigns)
      rescue Exception => e
        if TemplateError === e
          e.sub_template_of(template_file_name)
          raise e
        else
          raise TemplateError.new(@base_path, template_file_name, @assigns, template_source, e)
        end
      end
    end

    # Renders the template present at <tt>template_path</tt> (relative to the template_root). 
    # The hash in <tt>local_assigns</tt> is made available as local variables.
    def render(options = {}, old_local_assigns = {})
      if options.is_a?(String)
        render_file(options, true, old_local_assigns)
      elsif options.is_a?(Hash)
        options[:locals] ||= {}
        options[:use_full_path] = options[:use_full_path].nil? ? true : options[:use_full_path]

        if options[:file]
          render_file(options[:file], options[:use_full_path], options[:locals])
        elsif options[:partial] && options[:collection]
          render_partial_collection(options[:partial], options[:collection], options[:spacer_template], options[:locals])
        elsif options[:partial]
          render_partial(options[:partial], ActionView::Base::ObjectWrapper.new(options[:object]), options[:locals])
        elsif options[:inline]
          render_template(options[:type] || :rhtml, options[:inline], nil, options[:locals] || {})
        end
      end
    end

    # Renders the +template+ which is given as a string as either rhtml or rxml depending on <tt>template_extension</tt>.
    # The hash in <tt>local_assigns</tt> is made available as local variables.
    def render_template(template_extension, template, file_path = nil, local_assigns = {})
      if handler = @@template_handlers[template_extension]
        template ||= read_template_file(file_path, template_extension) # Make sure that a lazyily-read template is loaded.
        delegate_render(handler, template, local_assigns)
      else
        compile_and_render_template(template_extension, template, file_path, local_assigns)
      end
    end

    # Render the provided template with the given local assigns. If the template has not been rendered with the provided
    # local assigns yet, or if the template has been updated on disk, then the template will be compiled to a method.
    #

    # Either, but not both, of template and file_path may be nil. If file_path is given, the template
    # will only be read if it has to be compiled.
    #
    def compile_and_render_template(extension, template = nil, file_path = nil, local_assigns = {})
      # compile the given template, if necessary
      if compile_template?(template, file_path, local_assigns)
        template ||= read_template_file(file_path, extension)
        compile_template(extension, template, file_path, local_assigns)
      end

      # Get the method name for this template and run it
      method_name = @@method_names[file_path || template]
      evaluate_assigns                                    

      local_assigns = local_assigns.symbolize_keys if @@local_assigns_support_string_keys

      send(method_name, local_assigns) do |*name|
        instance_variable_get "@content_for_#{name.first || 'layout'}"
      end
    end

    def pick_template_extension(template_path)#:nodoc:
      if match = delegate_template_exists?(template_path)
        match.first
      elsif erb_template_exists?(template_path)
        'rhtml'
      elsif builder_template_exists?(template_path)
        'rxml'
      else
        raise ActionViewError, "No rhtml, rxml, or delegate template found for #{template_path}"
      end
    end

    def delegate_template_exists?(template_path)#:nodoc:
      @@template_handlers.find { |k,| template_exists?(template_path, k) }
    end

    def erb_template_exists?(template_path)#:nodoc:
      template_exists?(template_path, :rhtml)
    end

    def builder_template_exists?(template_path)#:nodoc:
      template_exists?(template_path, :rxml)
    end

    def file_exists?(template_path)#:nodoc:
      erb_template_exists?(template_path) || builder_template_exists?(template_path) || delegate_template_exists?(template_path)
    end

    # Returns true is the file may be rendered implicitly.
    def file_public?(template_path)#:nodoc:
      template_path.split('/').last[0,1] != '_'
    end

    private
      def full_template_path(template_path, extension)
        "#{@base_path}/#{template_path}.#{extension}"
      end

      def template_exists?(template_path, extension)
        file_path = full_template_path(template_path, extension)
        @@method_names.has_key?(file_path) || FileTest.exist?(file_path)
      end

      # This method reads a template file.
      def read_template_file(template_path, extension)
        File.read(template_path)
      end

      def evaluate_assigns
        unless @assigns_added
          assign_variables_from_controller
          @assigns_added = true
        end
      end

      def delegate_render(handler, template, local_assigns)
        handler.new(self).render(template, local_assigns)
      end

      def assign_variables_from_controller
        @assigns.each { |key, value| instance_variable_set("@#{key}", value) }
      end


      # Return true if the given template was compiled for a superset of the keys in local_assigns
      def supports_local_assigns?(render_symbol, local_assigns)
        local_assigns.empty? ||
          ((args = @@template_args[render_symbol]) && local_assigns.all? { |k,_| args.has_key?(k) })
      end
      
      # Check whether compilation is necessary.
      # Compile if the inline template or file has not been compiled yet.
      # Or if local_assigns has a new key, which isn't supported by the compiled code yet.
      # Or if the file has changed on disk and checking file mods hasn't been disabled. 
      def compile_template?(template, file_name, local_assigns)
        method_key = file_name || template
        render_symbol = @@method_names[method_key]

        if @@compile_time[render_symbol] && supports_local_assigns?(render_symbol, local_assigns)
          if file_name && !@@cache_template_loading 
            @@compile_time[render_symbol] < File.mtime(file_name)
          end
        else
          true
        end
      end

      # Create source code for given template
      def create_template_source(extension, template, render_symbol, locals)
        if extension && (extension.to_sym == :rxml)
          body = "xml = Builder::XmlMarkup.new(:indent => 2)\n" +
                 "@controller.headers['Content-Type'] ||= 'text/xml'\n" +
                 template
        else
          body = ERB.new(template, nil, trim_mode: @@erb_trim_mode).src
        end

        @@template_args[render_symbol] ||= {}
        locals_keys = @@template_args[render_symbol].keys | locals
        @@template_args[render_symbol] = locals_keys.inject({}) { |h, k| h[k] = true; h }

        locals_code = ""
        locals_keys.each do |key|
          locals_code << "#{key} = local_assigns[:#{key}] if local_assigns.has_key?(:#{key})\n"
        end

        "def #{render_symbol}(local_assigns)\n#{locals_code}#{body}\nend"
      end

      def assign_method_name(extension, template, file_name)
        method_name = '_run_'

        if extension && (extension.to_sym == :rxml)
          method_name << 'xml_'
        else
          method_name << 'html_'
        end

        if file_name
          file_path = File.expand_path(file_name)
          base_path = File.expand_path(@base_path)

          i = file_path.index(base_path)
          l = base_path.length

          method_name_file_part = i ? file_path[i+l+1,file_path.length-l-1] : file_path.clone
          method_name_file_part.sub!(/\.r(ht|x)ml$/,'')
          method_name_file_part.tr!('/:-', '_')
          method_name_file_part.gsub!(/[^a-zA-Z0-9_]/){|s| s[0].to_s}

          method_name += method_name_file_part
        else
          @@inline_template_count += 1
          method_name << @@inline_template_count.to_s
        end

        @@method_names[file_name || template] = method_name.intern
      end

      def compile_template(extension, template, file_name, local_assigns)
        method_key = file_name || template

        render_symbol = @@method_names[method_key] || assign_method_name(extension, template, file_name)
        render_source = create_template_source(extension, template, render_symbol, local_assigns.keys)

        line_offset = @@template_args[render_symbol].size
        line_offset += 2 if extension && (extension.to_sym == :rxml)

        begin
          unless file_name.blank?
            CompiledTemplates.module_eval(render_source, file_name, -line_offset)
          else
            CompiledTemplates.module_eval(render_source, 'compiled-template', -line_offset)
          end
        rescue Object => e
          if logger
            logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
            logger.debug "Function body: #{render_source}"
            logger.debug "Backtrace: #{e.backtrace.join("\n")}"
          end

          raise TemplateError.new(@base_path, method_key, @assigns, template, e)
        end

        @@compile_time[render_symbol] = Time.now
        # logger.debug "Compiled template #{method_key}\n  ==> #{render_symbol}" if logger
      end
  end
end

require 'action_view/template_error'
