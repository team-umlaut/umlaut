  //This script depends on jsr_class.js being imported by client too. 


  
  // Trim trailing slash from umlaut base url to normalize, if needed
  umlaut_base.replace(/\/$/,'');
  
  // Load prototype if not already present
  if( typeof(window.Prototype) == "undefined") {    
    document.write('<script type="text/javascript" src="'+umlaut_base+'/javascripts/prototype.js"><\/script>');
  }
  // load jsr_class.js if needed. 
  if( typeof(window.JSONscriptRequest) ==  "undefined") {
    document.write('<script type="text/javascript" src="'+umlaut_base+'/javascripts/embed/jsr_class.js"><\/script>');
  }

    function addEvent(obj, evType, fn)
    { 
      if (obj.addEventListener)
      { 
        obj.addEventListener(evType, fn, false); 
        return true; 
      } 
      else if (obj.attachEvent)
      { 
        var r = obj.attachEvent("on"+evType, fn); 
        return r; 
      } 
      else
      { 
        return false; 
      } 
    }
  
  // Loads a URL using the JSONscriptRequest to do a cross-domain AJAX. 
  function load_jsonp_url(url) {
    
      bObj = new JSONscriptRequest( url );
      bObj.buildScriptTag();
      bObj.addScriptTag();
  }

  
  // Callback called by jsonp technique. 
  function umlaut_partial_load_callback(jsonData) {
    var sections = jsonData.partial_html_sections.html_section;
    for ( var i = sections.length-1 ; i>=0 ; --i ) {
      var section = sections[i];
      
      config = umlaut_section_map[section.id];
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
      refresh_path = jsonData.partial_html_sections.in_progress.refresh_url_path;
      
      refresh_seconds = jsonData.partial_html_sections.in_progress.requested_wait_seconds;
    
      refresh_url = umlaut_host + refresh_path + "&umlaut.response_format=jsonp&umlaut.jsonp_callback=umlaut_partial_load_callback";
      
      window.setTimeout( "load_jsonp_url('" + refresh_url + "')", 4000 );
    }
  }

  function doOnLoad() {
    request = umlaut_base + '/resolve/partial_html_sections?umlaut.response_format=jsonp&umlaut.jsonp=umlaut_partial_load_callback&' + umlaut_openurl_kev_co;
  
    load_jsonp_url( request );
  }
  
  addEvent(window, 'load', doOnLoad);
  
