/* simple_visible_toggle.js.  Used for toggling visibility of error information. Can possibly be combined with more powerful expand_contract_toggle.js */
jQuery(document).ready(function($) {
   
    $(document).on("click", "a.simple_visible_toggle", function() {
       $(this).next().toggle(); 
    });
    
});
