# Still in progress. Uses illegal info:sudoc and info:gpo to get a
# a sudoc or a GPO Item Number for a given referent, and finds online
# availability, and/or links to GPO lookup for local depository with the
# item.
class Gpo < Service
  include MetadataHelper
  require 'hpricot'
  require 'open-uri' 
  
  
  def initialize(config)
    @display_name = "U.S. Government Printing Office"
    @gpo_item_find = true
    @sudoc_url_lookup = true
    super(config)
  end

  def service_types_generated
    a = []
    a.push(ServiceTypeValue["highlighted_link"]) if @gpo_item_find
    a.push(ServiceTypeValue["fulltext"]) if @sudoc_url_lookup
    return a
  end

  def handle(request)
    
    
    if ( @gpo_item_find )
      items = analyze_gpo_items(  get_gpo_item_nums(request.referent)  )
      
      items.each do |item, formats|
         # Generate URL to GPO Item Number lookup to finding
         # it in a repository near you. 
  
         request.add_service_response(:service => self, 
             :display_text => "Find in a Federal Depository Library",
             :url => gpo_item_lookup_url(item),
             :notes => "In " + formats.join(" or "),
             :service_type_value => "highlighted_link"
             )
      end
    end
    sudoc = get_sudoc(request.referent)
    
    if ( sudoc && @sudoc_url_lookup )
      add_links_from_sudoc(request, sudoc)
    end
    

    request.dispatched(self, true)
    
  end

  # Takes an array of string of GPO Items with formats in parens, groups
  # them by individual Item Number, identified by formats. 
  def analyze_gpo_items(items)
    item_hash = {}

    items.each do |i|      

      bare_item = i
      format_str = 'paper'

      # seperate the format marker from the base item number, if present.
      # if it's not present, means paper. 
      if ( i =~ /^(.*)\(([^\)]+)\)\s*$/  )      
        bare_item = $1.strip
        format_str = $2.strip
        format_str = "microform" if format_str == "MF"
      end
      
      item_hash[bare_item] ||= []
      
      item_hash[bare_item].push( format_str )      
    end
    
    return item_hash  
  end

  def gpo_item_lookup_url(item)
    return "http://catalog.gpo.gov/fdlpdir/locate.jsp?ItemNumber=" + CGI.escape(item)
  end

  def add_links_from_sudoc(request, sudoc)
    # Screen scrape the GPO catalog.
    
    response = open( gpo_sudoc_find_url(sudoc)  ).read

    hpricot = Hpricot(response)
    
    # Find each tr with class tr1, holding a td => The sixth td in there =>
    # one or more 'a' tags in there. These are links to fulltext. 
    links = hpricot.search('//tr[@class = "tr1"][td]/td:eq(6)/a')

    urls_seen = []
    
    links.each do |link|
      # The href is an internally pointing ILS link. But the text inside
      # the a is what we want, it's actually a URL, fortunately. . 

      url = link.inner_text
      unless urls_seen.include?(url)
      
        notes = nil
        if (links.length > 1)        
          notes = "via " + URI.parse(url).host
        end
  
        request.add_service_response(:service => self, 
         :display_text => @display_name,
         :url => url,
         :notes => notes,
         :service_type_value => "fulltext"
         )
         urls_seen.push( url )
      end         
    end
    
  end

  def gpo_sudoc_find_url(sudoc)
    return "http://catalog.gpo.gov/F/?func=find-a&find_code=GVD&request=#{CGI.escape('"'+sudoc+'"')}&local_base=GPO01PUB"
  end
  
end
