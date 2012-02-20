module Exlibris::Primo
# == Overview
# Exlibris::Primo::Holding represents a Primo holding.
# This class should be extended to create Primo source objects for 
# expanding holdings information, linking to Primo sources, and storing 
# additional metadata based on those sources.
#
# == Tips on Extending
# When extending the class, a few basics guidelines should be observed.
# 1.  A Exlibris::Primo::Holding is initialized from random Hash of parameters.
#     Instance variables are created from these parameters for use in the class.
#
# 2.  A Exlibris::Primo::Holding can be initialized from an input 
#     Exlibris::Primo::Holding by specifying the reserved
#     parameter name :holding, i.e. :holding => input_holding.
#     If the input holding has instance variables that are also specified in
#     the random Hash, the value in the Hash takes precedence.
#
# 3.  The following methods are available for overriding:
#     expand -    expand holdings information based on data source. default: [self]
#     dedup? -    does this data source contain duplicate holdings that need to be deduped? default: false
#
# 4.  The following instance variables will be saved in the view_data and will be available
#     to a local holding partial:
#     @record_id, @source_id, @original_source_id, @source_record_id,
#     @availlibrary, @institution_code, @institution, @library_code, @library,
#     @status_code, @status, @id_one, @id_two, @origin, @display_type, @coverage, @notes,
#     @url, @request_url, @match_reliability, @request_link_supports_ajax_call, @source_data
#
# 5.  Additional source data should be saved in the @source_data instance variable.
#     @source_data is a hash that can contain any number of string elements,
#     perfect for storing local source information.
#     @source_data will get saved in the view_data and will be available to a 
#     local holding partial.
#
# == Examples
# Example of Primo source implementations are:
# * Exlibris::Primo::Source::Aleph
  class Holding
    @base_attributes = [ :record_id, :source_id, :original_source_id, :source_record_id,
      :availlibrary, :institution_code, :institution, :library_code, :library,
      :status_code, :status, :id_one, :id_two, :origin, :display_type, :coverage, :notes,
      :url, :request_url, :match_reliability, :request_link_supports_ajax_call, :source_data ]
    # Make sure attribute you're aliasing in in base_attributes
    @attribute_aliases = { :collection => :id_one, :call_number => :id_two }
    @required_parameters = [ :base_url, :record_id, :source_id, 
      :original_source_id, :source_record_id, :availlibrary,
      :institution_code, :library_code, :id_one, :id_two, :status_code ]
    @parameter_default_values = { :vid => "DEFAULT", :config => {}, 
      :max_holdings => 10, :request_link_supports_ajax_call => false,
      :coverage => [], :source_data => {} }
    @decode_variables = { 
      :institution => {}, 
      :library => { :address => "libraries" },
      :status => { :address => "statuses" }
    }
    class << self; attr_reader :base_attributes, :attribute_aliases, :required_parameters, :parameter_default_values, :decode_variables end

    def initialize(parameters={})
      # Set attr_readers
      base_attributes = (self.class.base_attributes.nil?) ? 
        Exlibris::Primo::Holding.base_attributes : self.class.base_attributes
      base_attributes.each { |attribute|
        self.class.send(:attr_reader, attribute)
      }
      # Defensive copy the holding parameter.
      holding = parameters[:holding].clone unless parameters[:holding].nil?
      raise "Initialization error in #{self.class}. Unexpected holding parameter: #{holding.class}." unless holding.kind_of? Holding or holding.nil?
      # Copy the defensive copy of holding to self.
      holding.instance_variables.each { |name| 
        instance_variable_set((name).to_sym, holding.instance_variable_get(name)) 
      } if holding.kind_of? Holding
      # Add required instance variables, raising an exception if they're missing
      # Params passed in overwrite instance variables copied from the holding
      required_parameters = (self.class.required_parameters.nil?) ? 
        Exlibris::Primo::Holding.required_parameters : self.class.required_parameters
      required_parameters.each do |param|
        instance_variable_set(
          "@#{param}".to_sym, 
          parameters.delete(param) { 
            instance_variable_get("@#{param}") if instance_variable_defined?("@#{param}") }
        )
        raise_required_parameter_error param unless instance_variable_defined?("@#{param}")
      end
      # Set additional instance variables from passed parameters
      # Params passed in overwrite instance variables copied from the holding
      parameters.each { |param, value| 
        instance_variable_set("@#{param}".to_sym, value)
      }
      # If appropriate, add defaults to non-required elements
      parameter_default_values = (self.class.parameter_default_values.nil?) ? 
        Exlibris::Primo::Holding.parameter_default_values : self.class.parameter_default_values
      parameter_default_values.each { |param, default|
        instance_variable_set("@#{param}".to_sym, default) unless instance_variable_defined?("@#{param}")
      }
      # Set decoded fields
      decode_variables = (self.class.decode_variables.nil?) ? 
        Exlibris::Primo::Holding.decode_variables : self.class.decode_variables
      decode_variables.each { |var, decode_params|
        decode var, decode_params, true
      }
      # Deep link URL to record
      @url = primo_url if @url.nil?
      # Set source parameters
      @source_config = @config["sources"][source_id] unless @config["sources"].nil?
      @source_class = @source_config["class_name"] unless @source_config.nil?
      @source_url = @source_config["base_url"] unless @source_config.nil?
      @source_type = @source_config["type"] unless @source_config.nil?
      @source_data = {
        :source_class => @source_class,
        :source_url => @source_url,
        :source_type => @source_type
      }
      # Set aliases for convenience
      attribute_aliases = (self.class.attribute_aliases.nil?) ? 
        Exlibris::Primo::Holding.attribute_aliases : self.class.attribute_aliases
      attribute_aliases.each { |alias_name, method_name|
        begin
          self.class.send(:alias_method, alias_name.to_sym, method_name.to_sym)
        rescue NameError => ne
          raise NameError, "Error in #{self}. Make sure method, #{method_name}, is defined. You may need to add it to #{self} @base_attributes.\nRoot exception: #{ne.message}"
        end
      }
    end
    
    # Returns an array of self.
    # Should be overridden by source subclasses to map multiple holdings
    # to one availlibrary.
    def expand
      return [self]
    end

    # Determine if we're de-duplicating.
    # Should be overridden by source subclasses if appropriate.
    def dedup?
      return false
    end
    
    # Return this holding as a new holdings subclass instance based on source
    def to_source
      return self if @source_class.nil?
      begin
        # Get source class in Primo::Source module
         return Exlibris::Primo::Source.const_get(@source_class).new(:holding => self)
      rescue Exception => e
        Rails.logger.error("#{e.message}")
        Rails.logger.error("Class #{@source_class} can't be found in Exlibris::Primo::Source.  
          Please check primo.yml to ensure the class_name is defined correctly.  
          Not converting to source.")
        return self
      end
    end

    def [](key)
      raise "Error in #{self.class}. #{key} doesn't exist or is restricted." unless self.class.base_attributes.include?(key)
      method(key).call
    end

    protected
    def decode(var, decode_params={}, refresh=false)
      return instance_variable_get("@#{var}") unless (not instance_variable_defined?("@#{var}")) or refresh
      code_sym = (decode_params[:code].nil?) ? "#{var}_code".to_sym : decode_params[:code]
      code = instance_variable_get("@#{code_sym}")
      config_sym = (decode_params[:config].nil?) ? :config : decode_params[:config]
      config = instance_variable_get("@#{config_sym}")
      address = (decode_params[:address].nil?) ? "#{var}s" : decode_params[:address]
      instance_variable_set("@#{var}", 
        (config[address].nil? or config[address][code].nil?) ? 
          code : config[address][code]) unless code.nil?
    end

    # Returns Primo deep link URL to record
    def primo_url
      "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=#{@record_id}&institution=#{@institution_code}&vid=#{@vid}"
    end
 
    private
    # def self.add_attr_reader(reader)
    #   attr_reader reader.to_sym
    # end
    # 
    def raise_required_parameter_error(parameter)
      raise "Initialization error in #{self.class}. Missing required parameter: #{parameter}."
    end
  end
end
