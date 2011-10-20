Umlaut::Application.routes.draw do
  root :to => 'search#index'
  
  
  # Some things certain web browsers ask for that we don't
  # have. Give them a 404, suppress error in our logs.
  match '/_vti_bin/owssvr.dll' => 'application#error_404'
  match '/MSOffice/cltreq.asp' => 'application#error_404'
  
  # special for perma-links
  match 'go/:id' => 'store#index'
  
  
  # Special one for alpha list
  match 'journal_list/:id/:page' => 'search#journal_list', :defaults => { :page => 1, :id => 'A' }
  
  
  # Catch redirected from SFX A-Z and citation linker urls
  # v2 A-Z links redirected to umlaut, point to journal_list
  # code in journal_list filter picks out SFX URL vars for
  # letter. 
  match '/resolve/azlist/default' => 'search#journal_list', :page => 1, :id => 'A'
  
  # SFX v3 A-Z list url format
  match 'resolve/az' => 'search#journal_list', :page => 1, :id => 'A'
  
  # citation linker redirected to umlaut should point to journal search
  match '/resolve/cgi/core/citation-linker.cgi' => 'search#index'
  
  # Umlaut still depends on Rails 2 style default roots, sorry. 
  match '/:controller(/:action(/:id))'
  match ':controller/:action' => '#index'
  match ':controller/:action.:format' => '#index'
end


