require 'date'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Converting strings to other objects
      module Conversions
        # Form can be either :utc (default) or :local.
        def to_time(form = :utc)
          ::Time.send(form, *Date.parse.parse(self))
        end

        def to_date
          ::Date.parse(self)
        end
      end
    end
  end
end
