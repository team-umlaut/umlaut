# -*- encoding : utf-8 -*-
module Umlaut
  # Class to inject Umlaut routes, design copied from Blacklight project. 
  # you would do a:
  #    Umlaut::Routes.new(self, optional_args).draw 
  # in local
  # app routes.rb, that line is generated into local app by Umlaut generator.
  # options include :only and :except to limit what route groups are generated. 
  class Routes

    def initialize(router, options ={})
      @router = router
      @options = options
    end

    def draw
      route_sets.each do |r|
        self.send(r)
      end
    end

    protected

    def add_routes &blk
      @router.instance_exec(@options, &blk)
    end

    def route_sets
      (@options[:only] || default_route_sets) - (@options[:except] || [])
    end

    def default_route_sets
      [:permalinks, :a_z, :resolve, :open_search, :link_router, :export_email, :resources, :search]
    end

    module RouteSets
      def permalinks
        add_routes do |options|
          match 'go/:id' => 'store#index'
        end
      end
  
      # some special direct links to A-Z type searches, including
      # legacy redirects for SFX-style urls, to catch any bookmarks. 
      def a_z
        add_routes do |options|
          # Special one for alpha list
          match 'journal_list/:id/:page' => 'search#journal_list', :defaults => { :page => 1, :id => 'A' }
          
          
          # Catch redirected from SFX A-Z and citation linker urls
          # v2 A-Z links redirected to umlaut, point to journal_list
          # code in journal_list filter picks out SFX URL vars for
          # letter. 
          match '/resolve/azlist/default' => 'search#journal_list', :page => 1, :id => 'A'
          
          # SFX v3 A-Z list url format
          match 'resolve/az' => 'search#journal_list', :page => 1, :id => 'A'          
        end
      end
      
        # This is a legacy wild controller route that's not recommended for RESTful applications.
        # Note: This route will make all actions in every controller accessible via GET requests.
        # match ':controller(/:action(/:id(.:format)))'
        
      def resolve
        add_routes do |options|
          # ResolveController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.
          
          match 'resolve(/:action(/:id(.:format)))' => "resolve"
        end
      end
      
      def open_search
        add_routes do |options|
          # OpenSearchController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.
          
          match 'open_search(/:action(/:id(.:format)))' => "open_search"
        end
      end
      
      def link_router
        add_routes do |options|
          # LinkRouterController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.
          
          match 'link_router(/:action(/:id(.:format)))' => "link_router"
        end
      end
      
      def export_email
        add_routes do |options|
          # ExportEmailController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.
          
          match 'export_email(/:action(/:id(.:format)))' => "export_email"
        end
      end
      
      def resources
        add_routes do |options|
          # ResourceController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.
          
          match 'resource(/:action(/:id(.:format)))' => "resource"
        end
      end
      
      def search
        add_routes do |options|
          # SearchController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.
          
          match 'search(/:action(/:id(.:format)))' => "search"
        end
      end
   
    end
    include RouteSets
  end
end
