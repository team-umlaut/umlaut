// This is a manifest file that'll be compiled into including all
// umlaut files. It can be included in a rails application.js manifest
// as:
//         require 'umlaut'
// to include all umlaut js.  


// jquery and jquery-ui are required for umlaut, it's okay
// if the manifest chain ends up 'require'ing twice because
// it's mentioned in local manifest, sprockets is smart enough. 
//= require jquery
//= require bootstrap-transition
//= require bootstrap-modal
//= require bootstrap-typeahead
//= require bootstrap-collapse

// Require all js files inside the 'umlaut' subdir next to this file.  
//= require_tree './umlaut'


