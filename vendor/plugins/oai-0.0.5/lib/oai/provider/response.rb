require 'builder' unless defined?(Builder)

module OAI
  module Provider
    module Response
  
  class Base
    attr_reader :provider, :options
    
    class << self
      attr_reader :valid_options, :default_options, :required_options

      def valid_parameters(*args)
        @valid_options ||= []
        @valid_options = (@valid_options + args.dup).uniq
      end
      
      def default_parameters(options = {})
        @default_options ||= {}
        @default_options.merge! options.dup
      end
      
      def required_parameters(*args)
        valid_parameters(*args)
        @required_options ||= []
        @required_options = (@required_options + args.dup).uniq
      end
      
    end 

    def initialize(provider, options = {})
      @provider = provider
      @options = internalize(options)
      raise OAI::ArgumentException.new unless valid?
    end

    def response
      @builder = Builder::XmlMarkup.new
      @builder.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
      @builder.tag!('OAI-PMH', header) do 
        @builder.responseDate Time.now.utc.xmlschema
        @builder.request(provider.url, options)
        yield @builder
      end
    end

    private
    
    def header
      { 
        'xmlns' => "http://www.openarchives.org/OAI/2.0/",
        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
        'xsi:schemaLocation' => %{http://www.openarchives.org/OAI/2.0/
          http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd}
      }
    end
    
    def valid?
      return true if resumption?
      
      return true if self.class.valid_options.nil? and options.empty?
      
      if self.class.required_options
        return false unless (self.class.required_options - @options.keys).empty?
      end

      return false unless (@options.keys - self.class.valid_options).empty?

      populate_defaults
    end
    
    def populate_defaults
      self.class.default_options.each do |k,v|
        @options[k] = v.respond_to?(:call) ? v.call(self) : v if not @options[k]
      end
    end
    
    def resumption?
      if @options.keys.include?(:resumption_token) 
        return true if 1 == @options.keys.size
        raise OAI::ArgumentException.new
      end
    end
        
    # Convert our internal representations back into standard OAI options
    def externalize(value)
      value.to_s.gsub(/_[a-z]/) { |m| m.sub("_", '').capitalize }
    end
    
    def parse_date(value)
      return value if value.respond_to?(:strftime)
      
      # Oddly Chronic doesn't parse an UTC encoded datetime.  
      # Luckily Time does
      dt = Chronic.parse(value) || Time.parse(value)
      raise OAI::ArgumentError.new unless dt
      
      dt.utc
    end
    
    def internalize(hash = {})
      internal = {}
      hash.keys.each do |key|
        internal[key.to_s.gsub(/([A-Z])/, '_\1').downcase.intern] = hash[key].dup
      end
      
      # Convert date formated strings into internal time values
      # Convert date formated strings in dates.
      internal[:from] = parse_date(internal[:from]) if internal[:from]
      internal[:until] = parse_date(internal[:until]) if internal[:until]
      
      internal
    end
    
  end
  
end
end
end
