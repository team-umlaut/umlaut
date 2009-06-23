  //  Javascript helper for inserting partial html snippets from Umlaut on your page using the Umlaut partial HTML API.
  //
  // Load this script, and then call:
  // embedUmlaut(umlaut_base_url, kev_openurl, section_mapping, options);
  //
  // Function will load some external scripts, make a call to the umlaut partial_html_section
  // api, and load sections into the page according to section_mapping and options.
  // 
  // options is a hash of options.
  //  load_jsr_class => set to false to suppress loading of the external jsr_class.js file,
  //                    even if not already loaded. 
  // 
  //  load_prototype => by default, will load prototype if not already loaded. Set to false
  //                    to suppress this.
  //
  //  all-complete-callback => a javascript function to be called when all content is loaded.
  //
  // For more information on how to use this script, please see: 
  //
  // http://wiki.code4lib.org/index.php/Umlaut_partial_html_API_javascript_helper

  // Loads a URL using the JSONscriptRequest to do a cross-domain AJAX. 
  function load_jsonp_url(url) {
    
      bObj = new JSONscriptRequest( url );
      bObj.buildScriptTag();
      bObj.addScriptTag();
  }
  
  function umlaut_load_url(url) {
    
  }

  
  // In a bit of JS closure magic, we CREATE a function dynamically,
  // that will be the callback used by jsonp technique or that
  // otherwise loads section html. We create it dynamically so
  // it can use the section_mapping and options passed in.    
  function umlaut_create_callback_function(section_mapping, options) {
    
    return function(jsonData) {
      var sections = jsonData.partial_html_sections.html_section;
      for ( var i = sections.length-1 ; i>=0 ; --i ) {
        var section = sections[i];
        
        config = section_mapping[section.id];
        if (typeof(config) == "string") {
          config = {'host_div_id': config};
        }
        else if (typeof(config) == "undefined") {
          config = {};
        }
        host_div_id = config.host_div_id;
        
        if (config.before_update) {
          config.before_update.call(this, section.response_count.value);
        }
        
        if ( host_div_id && $(host_div_id) ) {
          //prototype update is used to execute <script> content,
          //among other things. 
          // prototype update WILL execute <script> tags contained in html. 
          var content = section.html_content ? section.html_content : ""; 
          $(host_div_id).update( content );
        }
        if (config.after_update) {
          config.after_update.call(this, section.response_count.value);
        }
        if( config.on_complete && section.service_load_complete.value) {
          config.on_complete.call(this, section.response_count.value);
        }
        
      }
      //Now do we need a reload?
      if ( jsonData.partial_html_sections.in_progress ) {
                   
        refresh_seconds = jsonData.partial_html_sections.in_progress.requested_wait_seconds;
            
        refresh_url = jsonData.partial_html_sections.in_progress.refresh_url
        
        window.setTimeout( "load_jsonp_url('" + refresh_url + "')", refresh_seconds * 1000 );
      }
      else {
        // all-complete callback 
        if ( options['all-complete-callback'] ) {
          options['all-complete-callback'].call(this);
        }
      }
    };
  }


  
  function embedUmlaut(umlaut_base, openurl_kev_co, section_mapping, options) {
    
    // Load external js files if we need them
    // load jsr_class.js if needed. 
    if (( typeof(window.JSONscriptRequest) ==  "undefined") &&
        options["load_jsr_class"] != false) {
      document.write('<script type="text/javascript" src="'+umlaut_base+'/javascripts/embed/jsr_class.js"><\/script>');
    }
    // Load prototype if not already present
    if (( typeof(window.Prototype) == "undefined") &&
        options["load_prototype"] != false ) {    
      document.write('<script type="text/javascript" src="'+umlaut_base+'/javascripts/prototype.js"><\/script>');
    }
    
     
     // this is tricky, but we're actually defining a global function
     // umlaut_partial_load_callback(...)
     umlaut_partial_load_callback = umlaut_create_callback_function(section_mapping, options);     

     // Create initial umlaut partial_html_sections url
     //normalize to have no trailing slash.     
     umlaut_base = umlaut_base.replace(/\/$/,''); 
     var request = umlaut_base + '/resolve/partial_html_sections?umlaut.response_format=jsonp&umlaut.jsonp=umlaut_partial_load_callback&' + openurl_kev_co;     
     //prototype-ism dom:loaded
     document.observe("dom:loaded", function() {load_jsonp_url(request);});     
  }
  
  
