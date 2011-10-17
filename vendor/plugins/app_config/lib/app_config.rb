# Author:: Daniel Owsianski (daniel-at-jarmark-dot-org)
# Edited by:: Nate Walker (kiwinewt-at-gmail-got-com)
# License::   MIT Licence, see application root.

module AppConfig
    # Name 'Base' for this class is required by
    # Initializer#initialize_framework_settings method.
    class Base #:nodoc
        @@parameters = ActiveSupport::OrderedOptions.new

        def self.method_missing(name, *arguments)
            @@parameters.method_missing(name, *arguments)
        end

        protected
        def self.parameters
            @@parameters
        end

        def self.has_param?(name)
            key = name.to_sym
            @@parameters.each{|i| return true if i.first == key}
            return false
        end
    end

    # When parameter with 'name' is nil method either returns
    # default value or (if default=nil) executes given block.
    # Note: either default value or block is allowed.
    def self.param(name, default=nil, &block)
        if block && default
            raise ArgumentError, "AppConfig cannot mix a default value argument with a block !"
        end

        value = Base.parameters[name]
        if value.nil? && block
            return yield(self)
        end

        value.nil? ? default : value
    end
    
    # Added to allow a parameter to be set/updated in real time.
    # This overwrites the current value but allows dynamically changing settings.
    def self.set_param(name, value=nil)
        Base.parameters[name] = value
    end

    # Returns true if a given parameter name exists internal parameters storage.
    # Note: parameter can has nil value
    def self.has_param?(name)
        Base.has_param?(name)
    end

    # Read-only access to config properties.
    def self.method_missing(name, *arguments)
        case
        when name.to_s=='[]'
            Base.parameters[arguments.first]
        when !arguments.empty?
            # small trick, methods with name= usual has arguments
            # so faster is to check is array empty than e.g. name.to_s[-1,1] == '='
            super
        else
            Base.parameters[name]
        end
    end
end
