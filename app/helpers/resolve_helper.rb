module ResolveHelper
  def load_custom_partial(action, view)
    begin
      render :partial=>action+'_'+view
     rescue ActionView::ActionViewError
      render :partial=>action+'_default'
     end
  end
  
  def search_opac_for_title(context_object)
    require 'sru'
    require 'uri'
    inst = Institution.find_by_default_institution('true')
    opac = inst.catalogs[0]
    if context_object.referent.metadata.has_key?('jtitle') and context_object.referent.metadata['jtitle'] != ""
      title = context_object.referent.metadata['jtitle'].gsub(/[^A-z0-9\s]/, '')
    elsif context_object.referent.metadata.has_key?('btitle') and context_object.referent.metadata['btitle'] != ""
      title = context_object.referent.metadata['btitle'].gsub(/[^A-z0-9\s]/, '')
    elsif context_object.referent.metadata.has_key?('title') and context_object.referent.metadata['title'] != ""
      title = context_object.referent.metadata['title'].gsub(/[^A-z0-9\s]/, '')
    else 
      return false
    end
    search = SRU::Client.new(opac.url)
    results = search.search_retrieve('dc.title all "'+title+'"', :recordSchema=>'mods', :startRecord=>1, :maximumRecords=>1)
    return false unless results.number_of_records > 0
    suffix = case results.number_of_records
             when 1 then ''
             else 'es'
             end
    link = "<ul><li><a href='http://gil.gatech.edu/cgi-bin/Pwebrecon.cgi?SAB1="+URI.escape(title.gsub(/\s(and|or)\s/, ' '))+"&BOOL1=all+of+these&FLD1=Title+%28TKEY%29&CNT=25&HIST=1' target='_blank'>"+results.number_of_records.to_s+" possible match"+suffix+" in "+opac.name+"</a></li></ul>"
    return link
  end
  
  def display_ill?
    return true if @dispatch_response.fulltext_links.empty? and @dispatch_response.print_locations.empty?
    return false unless @context_object.referent.format == 'journal'
    if @context_object.referent.metadata['atitle'] and @context_object.referent.metadata['atitle'] != ''
      return false
    else
      return true
    end
  end
  
  def display_closest_web_results?  
    return '' unless (@action_name == 'index' or @action_name == 'start') and @dispatch_response.relevant_links.length > 0
    if @cookies[:umlaut_web_results] and @cookies[:umlaut_web_results] == 'false'
      return 'hideWebResults();'
    end
    if @cookies[:umlaut_web_results] and @cookies[:umlaut_web_results] == 'true'
      return 'showWebResults();'
    end
    if @context_object.referent.format == 'journal' and (@context_object.referent.metadata['atitle'].nil? or @context_object.referent.metadata['atitle'] == '')
      return 'hideWebResults();'
    end
    return 'showWebResults();'
  end
end
