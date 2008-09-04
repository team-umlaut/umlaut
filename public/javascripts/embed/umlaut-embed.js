  //This script depends on jsr_class.js being imported by client too. 

  
  // Trim trailing slash from umlaut base url to normalize, if needed
  umlaut_base.replace(/\/$/,'');
  
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
      
      if ( host_div_id && $(host_div_id) ) {
        $(host_div_id).innerHTML = section.html_content; 
      }
      //alert(section.response_count.value);
      if (config.on_update) {
        config.on_update.call(this, section.response_count.value);
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

  
  request = umlaut_host + umlaut_base_path + '/resolve/partial_html_sections?umlaut.response_format=jsonp&umlaut.jsonp=umlaut_partial_load_callback&' + umlaut_openurl_kev_co;
  
  load_jsonp_url( request );
  
