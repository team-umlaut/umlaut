module OAIClient
  require 'oai'
  require 'rexml/document'
  
  def initialize(provider, identifier)
    @provider = provider    
    @identifier = identifier
    @client = OAI::Client.new @provider.url
  end
  
  def parse_response(response, metadataPrefix, record)
    meth = 'parse_'+metadataPrefix.to_s+'_record'
    if self.respond_to?(meth)
      self.send(meth, record, response)
    end    
  end
  
  def parse_oai_dc_record(record, response)
    
    REXML::XPath.each(record, "./metadata/oai_dc:dc/dc:subject", {"oai_dc"=>'http://www.openarchives.org/OAI/2.0/oai_dc/', 'dc'=>'http://purl.org/dc/elements/1.1/'}) { | subject |
        unless response.subjects.has_key?(@provider.name)
            @subjects[@provider.name] = []
        end
        response.subjects[@provider.name] << subject.get_text.value
    }
    
    REXML::XPath.each(record, "./metadata/oai_dc:dc/dc:description", {"oai_dc"=>'http://www.openarchives.org/OAI/2.0/oai_dc/', 'dc'=>'http://purl.org/dc/elements/1.1/'}) { | description |    
      response.description << {:source => @provider.name,
        :url => false,          
        :content => description.get_text.value}          
    }
  end 

  def get_metadata_formats
    response = @client.list_metadata_formats
    formats = []
    response.each { | format |
        formats << format.prefix
    }
    return formats
  end
  
  def do_simple_request
    response = client.get_record(:identifier=>@identifier)
    return {:oai_dc => response.record.metadata}  
  end
  
  def do_complex_request(formats)
    records = {}
    formats.each { | format |
      response = @client.get_record({:identifier=>@identifier, :metadata_prefix=>format})
      records[format.to_sym] = response.record.metadata
    }
    return records
  end

end