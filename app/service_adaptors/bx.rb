# Uses bX recommender service to generate links to "similar" articles.
#
# REQUIREMENTS: You must be an bX customer.  Required field "token" is specific to your institution.
# Optional fields:
#   max_records - max number of records returned; default 10
#   threshold - minimum score a recommendation must have in order to be included in the results; scores range from 0 to 100; default 50
#   openurl_base - base for other link resolver; default "/resolve"
#   source - values "local"|"global"; default "global"
class Bx < Service
  require  'open-uri'
  require 'nokogiri'

  required_config_params :token

  def initialize(config)
    @display_name = "Bx"
    @base_url = "http://recommender.service.exlibrisgroup.com/service/recommender/openurl"
    @max_records = "5"
    @threshold = "50"
    @source = "global"
    @openurl_base  = "/resolve"
    super(config)
  end

  def service_types_generated
    return [ServiceTypeValue[:similar]]
  end

  def handle(request)
    format = "rss"
    bx_url = "#{@base_url}?res_dat=format%3D#{format}%26source%3D#{@source}%26token%3D#{@token}%26maxRecords%3D#{@max_records}%26threshold%3D#{@threshold}%26baseUrl%3D#{@openurl_base}&#{request.to_context_object.kev}"
    response = open(bx_url)
    Rails.logger.debug("bX URL #{bx_url.inspect}")
    response_xml_str = response.read
    Rails.logger.debug("bX Response #{response_xml_str.inspect}")
    response_xml = Nokogiri::XML(response_xml_str)
    response_xml.search("//item").each do |item|
      title = item.at("title").inner_text
      author = item.at("author").inner_text
      display_text = (author.nil?)? "#{title}" : "#{author}; #{title}"
      url = item.at("link").inner_text
      request.add_service_response( 
         :service=>self, 
         :display_text => display_text, 
         :url => url, 
         :service_type_value => :similar)          
    end
    return request.dispatched(self, true)
  end

end