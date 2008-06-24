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
      
      var host_div_id = umlaut_section_map[section.id];
      if ( host_div_id ) {
        var host_div = document.getElementById( host_div_id );
        if ( host_div ) {
          host_div.innerHTML = section.html_content; 
        }        
      }      
    }
    //Now do we need a reload?
    if ( jsonData.partial_html_sections.in_progress ) {
      refresh_path = jsonData.partial_html_sections.in_progress.refresh_url_path;
      
      refresh_seconds = jsonData.partial_html_sections.in_progress.requested_wait_seconds;
    
      refresh_url = umlaut_base + refresh_path + "&umlaut.response_format=jsonp&umlaut.jsonp_callback=umlaut_partial_load_callback";
      
      window.setTimeout( "load_jsonp_url('" + refresh_url + "')", 4000 );
    }
  }

  
  request = umlaut_base + '/resolve/partial_html_sections?umlaut.response_format=jsonp&umlaut.jsonp=umlaut_partial_load_callback&' + umlaut_openurl_kev_co;
  
  load_jsonp_url( request );
  
