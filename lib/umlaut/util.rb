module Umlaut
  module Util

    module_function

    # Provide a prettified and cleaned exception backtrace array from an exception,
    # using the Rails backtrace cleaner, as configured in the app. Umlaut configures
    # it, in an initializer declared in umlaut.rb, to prettify and include Umlaut trace lines. 
    #
    # This will produce a stack trace similar to what Rails logs by default for uncaught
    # exceptions. We use it for exception logging in several places. 
    #
    # Pass in the exception itself, not `exception.backtrace`. 
    def clean_backtrace(exception)
      if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        trace = Rails.backtrace_cleaner.clean(exception.backtrace)
        trace = Rails.backtrace_cleaner.clean(exception.backtrace, :all) if trace.empty?
        return trace
      else
        return exception.backtrace
      end
    end
  end
end