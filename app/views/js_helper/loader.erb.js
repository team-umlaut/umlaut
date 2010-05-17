(function($) {
    
    function Loader() {
      this.load = function(option_list) {
        if (option_list == undefined) {
          option_list = ["all_resolve"]; 
        }
        
        for(var i = 0; i < option_list.length ; i++) {
          var option = option_list[i];
          $("head").append( this.source[option] );
        }
      };
    }
    Loader.prototype.source = {
      <% # At the moment the only JS behavior that's really supported is 
         # expand/contract, too hard to get the dialogs working. So no need
         # for jquery-ui, forget it. 
         [].each do |option| %>
      
      "<%= option.to_s %>": "<%= escape_javascript(render_javascript_behaviors(option)) %>",
      
      <% end %>
            
      
      "all_resolve": "<%= escape_javascript( javascript_include_tag("jquery/umlaut/expand_contract_toggle.js", "jquery/umlaut/simple_visible_toggle.js")) %>"
    };
    
    //Export it to the global object. 
    if (window.Umlaut == undefined)
      window.Umlaut = new Object();
    window.Umlaut.Loader = Loader;
    
})(jQuery);
