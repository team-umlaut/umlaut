module Exlibris::Primo
  # Class for handling Primo TOCs from links/addlink
  class RelatedLink
    @base_attributes = [ :record_id, :addlink, :url, :display,  :notes ]
    class << self; attr_reader :base_attributes end
    def initialize(options={})
      base_attributes = (self.class.base_attributes.nil?) ? 
        Exlibris::Primo::RelatedLink.base_attributes : self.class.base_attributes
      base_attributes.each { |attribute|
        self.class.send(:attr_reader, attribute)
      }
      options.each { |option, value| 
        self.instance_variable_set(('@'+option.to_s).to_sym, value) 
      }
    end
  end
end