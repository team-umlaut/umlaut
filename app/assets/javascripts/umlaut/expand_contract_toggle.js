/* expand_contract_toggle.js: Support for show more/hide more in lists of umlaut content.
   
   The JS needs to swap out the image for expand/contract toggle. AND we need
   the URL it swaps in to be an ABSOLUTE url when we're using partial html
   widget. 
   
   So we swap in a non-fingerprinted URL, even if the original was asset
   pipline fingerprinted. sorry, best way to make it work!
*/
jQuery(document).ready(function($) {
  $(".expand_contract_toggle").live("click", function(event) {
    event.preventDefault();
    var content = $(this).next(".expand_contract_content");
    var icon = $(this).parent().find('i.expand_contract_toggle');
    if (content.is(":visible")) {
      icon.removeClass("umlaut_icons-list-open").addClass("umlaut_icons-list-closed");
      $(this).find(".expand_contract_action_label").text("Show ");
      content.hide();
    } else {
      icon.removeClass("umlaut_icons-list-closed").addClass("umlaut_icons-list-open");
      $(this).find(".expand_contract_action_label").text("Hide ");
      content.show();
    }
    return false;
  });
});