/* ajax_windows.js.  Support for modal popup windows in Umlaut items. */
jQuery(document).ready(function($) {
   
    var shared_modal_d = $("<div></div>").dialog({autoOpen: false, modal: true, width: "400px"}) ;

    $("a.ajax_window").live("click", function(event) {                
        
        $(shared_modal_d).load(  this.href, function() {
            var heading = shared_modal_d.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
            $(shared_modal_d).dialog("option", "title", heading.text());
            $(shared_modal_d).dialog("open");
        });
        return false;
    });
    
    function ajax_form_catch(event) {
        $(shared_modal_d).load( $(event.target).closest("form").attr("action"), $(event.target).closest("form").serialize(), function() {
           var heading = shared_modal_d.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
           $(shared_modal_d).dialog("option", "title", heading.text());
           $(shared_modal_d).dialog("open");
           
        });
        return false;
    }
    
    //Trapping two events, click on the submit button or submit on the form
    //is strangely needed in IE7 to trap both return-in-field submits
    //and click-on-button submits. In FF just the second "submit" version
    //is sufficient. 
    $("form.modal_dialog_form input[type=submit]").live("click", ajax_form_catch );    
    $("form.modal_dialog_form").live( "submit", ajax_form_catch);
    

    
});
