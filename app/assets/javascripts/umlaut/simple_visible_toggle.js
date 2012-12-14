/* simple_visible_toggle.js.  Used for toggling visibility of error information. Can possibly be combined with more powerful expand_contract_toggle.js */
jQuery(document).ready(function($) {
    $("a.simple_visible_toggle").live("click", function(event) {
      event.preventDefault();
       $(this).next().toggle(); 
    });
});
