ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"
  map.connect '', :controller => "search", :action=>"index"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # special for perma-links
  map.connect 'go/:id', :controller=>"store"
  
  # Special one for alpha list
  map.connect "journal_list/:id/:page", :controller=>'search', :action=>'journal_list', :defaults=>{:page => 1, :id=> 'A'}


  # Catch redirected from SFX A-Z and citation linker urls
  # v2 A-Z links redirected to umlaut, point to journal_list
  # code in journal_list filter picks out SFX URL vars for
  # letter. 
  map.connect '/resolve/azlist/default', :controller=>'search', :action=>'journal_list', :page=>1, :id=>'A'

  # SFX v3 A-Z list url format
  map.connect 'resolve/az', :controller=>'search', :action=>'journal_list', :page=>1, :id=>'A'
  
  # citation linker redirected to umlaut should point to journal search
  map.connect '/resolve/cgi/core/citation-linker.cgi', :controller=>'search'

  
  # Install the default route as the lowest priority.
  # Sometimes id is an OpenURL 0.1 identifier, and sticking it in the
  # path can not only mess up the OpenURL, but can confuse Rails when
  # the identifier itself includes a /. So we only put it in path
  # if the id is all numbers, and everyone is happy. 
  map.connect ':controller/:action/:id', :requirements => {:id => /\d*/}
  map.connect ':controller/:action' # id will end up in ?id=whatever
  

end
