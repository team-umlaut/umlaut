/* update_html.js:  Provide functions to update content on page with background responses from Umlaut. Used by Umlaut itself, as well as by third party callers.*/
(function($) {
   
    function SectionTarget(config) {
       //Add properties from config to ourself
       $.extend(this, config);
       
       //Defaults
       if (this.selector == undefined)
         this.selector = "#" + this.umlaut_section_id;
       if (this.position == undefined)
         this.position = "html";
              
    }
    //Callback default to no-op function please.    
    var noop = function() {};
    SectionTarget.prototype.before_update = noop;
    SectionTarget.prototype.after_update = noop;
    SectionTarget.prototype.complete = noop;
    
    SectionTarget.prototype.ensure_placement_destination = function() {
        if ( this.selector == undefined) {
          return null; 
        }
        
        //Already have it cached?
        if ( this.host_div_element ) {
          return this.host_div_element;
        }                        
        
        var new_div = $('<div class="umlaut" style="display:none"></div>');        
        // Find the first thing matched by selector, and call the
        // method specified in "action" string on it, giving it our
        // HTML to replace. This works because our actions are
        // all arguments that will take one method: html, before, after, append,
        // prepend.                       
        $(this.selector).eq(0)[ this.position  ]( new_div );
        
        //Cache for later
        this.host_div_element = new_div;
        return this.host_div_element;
      };
    

  // Define an object constructor on the global window object
  // For our UmlautHtmlUpdater object. 
  function HtmlUpdater(umlaut_base, context_object) {
    if (context_object == undefined)
      context_object = "";      
    
    // Remove query string (if present)
    umlaut_base = umlaut_base.replace(/\?.*$/, '')
    // Remove trailing slash
    umlaut_base = umlaut_base.replace(/\/$/,'');
    this.umlaut_uri =  umlaut_base + '/resolve/partial_html_sections?umlaut.response_format=json&' + context_object;
        
    this.section_targets = [];
           
    this.add_section_target = function(config) {
      this.section_targets.push( new SectionTarget(config) ); 
    };
    
    //default no-op call-backs
    this.complete = noop;
    this.before_update = noop;
    this.after_update = noop;
    
    
    //Code for seeing if a URI is same origin or not borrowed from jQuery
    this.is_remote_url = function(url) {
      var regexp = /^(\w+:)?\/\/([^\/?#]+)/;
      var parts = regexp.exec( url );
      return (parts && (parts[1] && parts[1] !== location.protocol || parts[2] !== location.host));
    }
    
    this.update = function() {
      // Need to capture because we won't have 'this' inside the ajax
      // success handler. 
      var myself = this;       
      var dataType = this.is_remote_url( this.umlaut_uri ) ? "jsonp" : "json";
       $.ajax({
             url: myself.umlaut_uri,
             dataType: dataType,
             jsonp: "umlaut.jsonp",
             error: function() {
               $.error("Problem loading background elements.");
             },
             success: function(umlaut_response) {
              for (var i = 0; i < myself.section_targets.length; i++) {
                  var section_target = myself.section_targets[i];                                
                 
                  var umlaut_html_section = myself.find_umlaut_response_section(umlaut_response, section_target.umlaut_section_id);
                                    
                  if (umlaut_html_section == undefined) {
                    continue;
                  }                  
                  var count = null;
                  if (typeof umlaut_html_section.response_count != "undefined") { 
                    count = parseInt(umlaut_html_section.response_count.value);
                  }
                  var existing_element = section_target.ensure_placement_destination();
                  var new_element = $('<div class="umlaut" style="display:none" class="' + section_target.umlaut_section_id +'"></div>');
                  new_element.html(umlaut_html_section.html_content);

                  
                  var should_continue = section_target.before_update(new_element, count, section_target);
                  if (should_continue != false) {
                    should_continue = myself.before_update(new_element, count, section_target);
                  }
                                    
                  if (should_continue != false) {                    
                    existing_element.replaceWith(new_element);
                    
                    section_target.host_div_element = new_element;

                    new_element.show();
                  
                    section_target.after_update(new_element, count, section_target);
                    myself.after_update(new_element, count, section_target);
                    
                  }
               }
               
               //Do we need to update again?
               if (umlaut_response.partial_html_sections.in_progress) {   
                  //Fix our update URI to be the one umlaut suggests
                  //Except strip out the umlaut.jsonp parameter, jquery is
                  //going to add that back in as desired. 
                  myself.umlaut_uri = 
                    umlaut_response.partial_html_sections.in_progress.refresh_url.replace(/[?;&]umlaut\.jsonp=[^;&]+/, '');
                  
                  
                  var refresh_seconds = 
                    umlaut_response.partial_html_sections.in_progress.requested_wait_seconds;
                  window.setTimeout(function() { myself.update();  }, refresh_seconds * 1000); 
                  
               } else {
                 myself.complete();
                 for (var i = 0; i < myself.section_targets.length; i++) {
                   var section_target = myself.section_targets[i];
                   section_target.complete(section_target);
                 }
               }
               
             }
       });
    };
    this.find_umlaut_response_section = function(response, id) {
      return $.grep(response.partial_html_sections.html_section, function(section) {
        return section.id == id;
      })[0];
    };
    
  };
  
  //Put it in a global object, leave space for other things in "Umlaut" later.
  if (window.Umlaut == undefined)
    window.Umlaut = new Object();
  window.Umlaut.HtmlUpdater = HtmlUpdater; 
  
  /* LEGACY Loader was recommended for loading Umlaut JS behaviors
     in an external page, for JQuery Content Utility. 
     
     var loader = new Umlaut.Loader();
     loader.load();
     
     We will provide just enough code to keep that from
     error'ing (and halting js execution), although at present it does not 
     actually load the JS behaviors using new style, app wont' have
     JS behaviors. */
        
    window.Umlaut.Loader = function() {
      this.load = function(option_list) {
        // log problem in browsers that support it. 
        if (typeof console != "undefined" && typeof console.log != "undefined") {
          console.log("WARN: Umlaut.Loader no longer supported in Umlaut 3.x, you may have not loaded Umlaut JS Behaviors as desired. See Umlaut documentation for new way.");
          
        }                 
      }
    }
  
  
})(jQuery);

