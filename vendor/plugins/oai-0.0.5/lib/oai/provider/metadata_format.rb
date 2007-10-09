module OAI::Provider::Metadata
  # == Metadata Base Class
  #
  # MetadataFormat is the base class from which all other format classes 
  # should inherit.  Format classes provide mapping of record fields into XML.
  #
  # * prefix - contains the metadata_prefix used to select the format
  # * schema - location of the xml schema
  # * namespace - location of the namespace document
  # * element_namespace - the namespace portion of the XML elements
  # * fields - list of fields in this metadata format
  #
  # See OAI::Metadata::DublinCore for an example
  #
  class Format
    include Singleton
    
    attr_accessor :prefix, :schema, :namespace, :element_namespace, :fields
    
    # Provided a model, and a record belonging to that model this method
    # will return an xml represention of the record.  This is the method
    # that should be extended if you need to create more complex xml
    # representations.
    def encode(model, record)
      if record.respond_to?("to_#{prefix}")
        record.send("to_#{prefix}")
      else
        xml = Builder::XmlMarkup.new
        map = model.respond_to?("map_#{prefix}") ? model.send("map_#{prefix}") : {}
          xml.tag!("#{prefix}:#{element_namespace}", header_specification) do
            fields.each do |field|
              values = value_for(field, record, map)
              values.each do |value|
                xml.tag! "#{element_namespace}:#{field}", value
              end
            end
          end
        xml.target!
      end
    end

    private

    # We try a bunch of different methods to get the data from the model.
    #
    # 1.  Check if the model defines a field mapping for the field of 
    #     interest.
    # 2.  Try calling the pluralized name method on the model.
    # 3.  Try calling the singular name method on the model
    def value_for(field, record, map)
      method = map[field] ? map[field].to_s : field.to_s
      
      methods = record.public_methods(false)
      if methods.include?(method.pluralize)
        record.send method.pluralize
      elsif methods.include?(method)
        record.send method
      else
        []
      end
    end

    # Subclasses must override
    def header_specification
      raise NotImplementedError.new
    end

  end
  
end

Dir.glob(File.dirname(__FILE__) + '/metadata_format/*.rb').each {|lib| require lib}
