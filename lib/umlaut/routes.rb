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
      # :admin is not included by default, needs to be turned on. 
      (@options[:only] || default_route_sets) - (@options[:except] || []) + (@options[:admin] == true ? [:admin] : [])
    end

    def default_route_sets
      [:root, :permalinks, :a_z, :resolve, :open_search, :link_router, :export_email, :resources, :search, :javascript, :feedback]
    end

    module RouteSets
      # for now include root generation in Umlaut auto-generation
      def root
        add_routes do |options|
          root :to => "search#index"
        end
      end
      
      def permalinks
        add_routes do |options|
          get 'go/:id' => 'store#index'
        end
      end
  
      # some special direct links to A-Z type searches, including
      # legacy redirects for SFX-style urls, to catch any bookmarks. 
      def a_z
        add_routes do |options|
          # Special one for alpha list
          get 'journal_list(/:id(/:page))' => 'search#journal_list', :defaults => { :page => '1', :id => 'A' }
          
          
          # Catch redirected from SFX A-Z and citation linker urls
          # v2 A-Z links redirected to umlaut, point to journal_list
          # code in journal_list filter picks out SFX URL vars for
          # letter. 
          get '/resolve/azlist/default' => 'search#journal_list', :page => 1, :id => 'A'
          
          # SFX v3 A-Z list url format
          get 'resolve/az' => 'search#journal_list', :page => 1, :id => 'A'          
        end
      end
      
        # This is a legacy wild controller route that's not recommended for RESTful applications.
        # Note: This route will make all actions in every controller accessible via GET requests.
        # match ':controller(/:action(/:id(.:format)))'
        
      def resolve
        add_routes do |options|
          # Prevent resolve/index/:id, should always be resolve/index?id=foo, 
          # to keep OpenURLs good, and avoid errors with DOI's with slashes in em etc. 
          get 'resolve(.:format)' => "resolve#index"

          # ResolveController still uses rails 2.0 style 'wildcard' routes, 
          # TODO tighten this up to only match what oughta be matched.           
          # Note: This route will make all actions in this controller accessible via GET requests.          
          get 'resolve(/:action(/:id(.:format)))' => "resolve"

          get 'resolve/get_permalink'
          match 'resolve/display_coins', :via => [:get, :post]
          get 'resolve/background_status'
          get 'resolve/partial_html_sections'
          get 'resolve/api'
        end
      end
      
      def open_search
        add_routes do |options|
          get 'open_search(/index)' => "open_search#index"
        end
      end
      
      def link_router
        add_routes do |options|
          get 'link_router(/index)' => "link_router#index"
        end
      end
      
      def export_email
        add_routes do |options|
          get  'export_email/email'      => "export_email#email"
          post 'export_email/send_email' => "export_email#send_email"

          get  'export_email/txt'      => "export_email#email"
          post 'export_email/send_txt'   => "export_email#send_txt"
        end
      end
      
      def resources
        add_routes do |options|
          get 'resource/proxy'
        end
      end
      
      def search
        add_routes do |options|
          get 'search(/index)' => "search#index"
          get 'search/journals'
          get 'search/books'
          get 'search/journal_search'
          get 'search/journal_list'
          get 'search/auto_complete_for_journal_title'
        end
      end
      
      def javascript
        add_routes do |options|
          # Legacy location for update_html.js used by JQuery Content Utility
          # to embed JS on external sites. Redirect to new location. 
          # Intentionally non-fingerprinted, most efficient thing
          # we can do in this case is let the web server take care
          # of Last-modified-by etc headers. 
          get 'javascripts/jquery/umlaut/update_html.js' => redirect("/assets/umlaut/update_html.js", :status => 301)
          
          # The loader doens't work _exactly_ like the new umlaut-ui.js, but
          # it's close enough that it'll work better redirecting than just
          # 404'ing. 
          get 'js_helper/loader' => redirect("/assets/umlaut_ui.js")
          
          
          get 'images/spinner.gif' => redirect("/assets/spinner.gif")
        end
      end

      def feedback
        add_routes do |options|
          get 'feedback(/:request_id)', :to => "feedback#new", :as => "feedback"
          post 'feedback(/:request_id)' => 'feedback#create'
        end
      end
      
      def admin
        add_routes do |options|
          namespace "admin" do
            get 'service_errors(/:service_id)' => "service_errors#index"
          end
        end
      end
   
    end
    include RouteSets
  end
end
