module OpenSearchHelper
  
  def opensearch_template_url
    url_for(:controller => "search", :action => "journal_search", :rfr_id => umlaut_config.lookup('rfr_id.opensearch'), :'umlaut.title_search_type' => 'contains', :only_path => false ) + '&amp;rft.jtitle={searchTerms}'
  end
  
end
