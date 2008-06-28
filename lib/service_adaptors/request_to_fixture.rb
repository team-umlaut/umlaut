# This service helps create fixture data for testing purposes.
# It really just writes out to Yaml the Request (attributes only), Referent,
# and ReferentValues. 
# The Request, Referent and ReferentValues must be cut and pasted into the 
# relevant fixture files to be used in testing.
 

class RequestToFixture < Service
  required_config_params :file
  attr_reader :file
  
  def service_types_generated  
  end
  
  def initialize(config)
    super(config)
  end
  
  def handle(request)
    final_string = ''
    fh = File.open(@file, 'a')
    dump_request(request, final_string)
    dump_referent_values(request, final_string)    
    
    cleanup(final_string)
    fh.puts final_string
    fh.close
    return request.dispatched(self, true)
  end
  
  def dump_request(request, string)
    #YAML.dump(request, fh)
    dump_proper(request, string, 'request')
    put_cutline(string)
    dump_proper(request.referent, string, 'referent')
    put_cutline(string)
  end
  
  def dump_referent_values(request, string)
    referent_values = request.referent.referent_values.sort_by{|rv| rv.id}
      referent_values.each do |rv|
        dump_proper(rv, string, 'referent_value')
      end
      put_cutline(string)
  end
  
  def dump_proper(data, string, type)
    values = {}
    data.attributes.each do |var, val|
      values[var] = val
    end
    fixture = {}
    fixture[type + '_' + data.id.to_s] = values
    string << YAML.dump(fixture)
    
  end
  
  def put_cutline(string)
    string << "\n-------------CUT HERE----------------\n"
  end
  
  # removes lines that only contain three dashes. These mess up our fixtures.
  def cleanup(string)
    string.gsub!(/^--- $/, "")
  end
  
  
end
