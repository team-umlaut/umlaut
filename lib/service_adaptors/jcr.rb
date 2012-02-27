# encoding: UTF-8

# Link to Thomson JCR impact report for journal title. 
#
#
# REQUIREMENTS: You must be an ISI customer if you want these links to actually
# work for your users. Off-campus users should be sent through EZProxy, see
# the EZProxy plug-in.
# 
# You need to register for the  the Thomson 'Links Article Match Retrieval'
# (LAMR) service api, which is used here (and also in the Isi plugin). To
# register, see:
# http://wokinfo.com/products_tools/products/related/amr/
#
# You register by IP address, so no API key is needed once your registration
# goes through. 
#
# If you later need to change the IP addresses entitled to use this API, use
# http://scientific.thomson.com/scientific/techsupport/cpe/form.html.
# to request a change. 
class Jcr < Service
  require  'open-uri'
  require 'nokogiri'
  require 'net/http'
  require 'builder'
  
  include MetadataHelper
  
  
  def service_types_generated
    return [ServiceTypeValue[:highlighted_link]]
  end

  def initialize(config)
    #defaults
    @wos_app_name = "Umlaut"
    @display_name = "Journal Citation Reports\xc2\xae" # trademark symbol, utf-8
    @link_text = "Journal impact factor"
    @api_url = "https://ws.isiknowledge.com/cps/xrpc"
    @include_for_article_level = true
    
    @credits = {
      @display_name => "http://thomsonreuters.com/products_services/science/science_products/a-z/journal_citation_reports/"
    }
    
    super(config)
  end

  def handle(request)
    
    unless ( sufficient_metadata?(request.referent))
       return request.dispatched(self, true)
    end
        
    xml = gen_lamr_request(request)
    
    isi_response = do_lamr_request(xml)
    
    add_responses( request, isi_response )
    
    return request.dispatched(self, true)
  end

  # Need an ISSN. 
  def sufficient_metadata?(referent)
    return ! referent.issn.blank? 
  end

  # produces XML to be posted to Thomson 'Links Article Match Retrieval' service api. 
  def gen_lamr_request(request)
    output = ""
    
    builder = Builder::XmlMarkup.new(:target => output, :indent => 2)
    builder.instruct!(:xml, :encoding => "UTF-8")    

    builder.request(:xmlns => "http://www.isinet.com/xrpc41", :src => "app.id=Umlaut") do
      builder.fn(:name => "LinksAMR.retrieve") do
        builder.list do
          # first map is authentication info. empty 'map' element since we are IP authenticated. 
          builder.map
          # specify what we're requesting
          builder.map do
            builder.list(:name=>"JCR") do
              builder.val("impactGraphURL")              
            end
          end
          # specify our query
          builder.map do            
            builder.map(:name => "cite_id") do
              metadata = request.referent.metadata
              if (issn = request.referent.issn)                              
                issn = issn[0,4] + '-' + issn[4,7] unless issn =~ /\-/
                builder.val(issn, :name => "issn")
              end
              # Journal title.  
              if (! metadata['jtitle'].blank? )
                builder.val(metadata['jtitle'], :name => "stitle" )
              elsif (! metadata['title'].blank? )
                builder.val(metadata['title'], :name => 'stitle' )
              end
            end
          end          
        end
      end
    end
    return output
  end

  def do_lamr_request(xml)
    uri = URI.parse(@api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if (uri.scheme == 'https')

    headers = {'Content-Type' => 'application/xml'}
    
    return http.post(uri.request_uri, xml, headers)
  end

  def add_responses(request, isi_response)
    # raise if it's an HTTP error code
    isi_response.value
    
    nokogiri = Nokogiri::XML(isi_response.body)

    # Check for errors.
    if (error = (nokogiri.at('val[@name = "error"]') || nokogiri.at('error') || nokogiri.at('null[@name = "error"]')))
      raise Exception.new("Third party service error: #{error.inner_text}")
    end


    results = nokogiri.at('map[@name ="cite_id"] map[@name="JCR"]')

    impact_url = results.at('val[@name ="impactGraphURL"]')
    
    if (impact_url )
      request.add_service_response(:service=>self, 
        :display_text => @link_text,          
        :url => impact_url.inner_text, 
        :service_type_value => :highlighted_link,
        :debug_info => "url: #{impact_url.inner_text}")
    end
    
    
  end
  
end
