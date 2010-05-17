/* expand_contract_toggle.js: Support for show more/hide more in lists of umlaut content. */
jQuery(document).ready(function($) {
   
    $(".expand_contract_toggle").live("click", function() {
        var content = $(this).next(".expand_contract_content");
        var icon = $(this).parent().find('img.toggle_icon');
        
        if (content.is(":visible")) {                    
          icon.attr("src", icon.attr("src").replace("list_open.png", "list_closed.png"));
          $(this).find(".expand_contract_action_label").text("Show ");
          
          content.hide();
          
        }
        else {                    
          icon.attr("src", icon.attr("src").replace("list_closed.png", "list_open.png"));
          $(this).find(".expand_contract_action_label").text("Hide ");
          content.show();
        }
        
        return false;
    });
    
    
});
