/* expand_contract_toggle.js: Support for show more/hide more in lists of umlaut content.
  
  Expand/collapse elements are already controlled via Bootstrap toggle,
  this just adds some additional behavior in hooks to change our labels
  and disclosure icons appropriately, and prevent following non-js href links. 
*/
jQuery(document).ready(function($) {
  $(document).on("click", ".collapse-toggle", function(event) {
    event.preventDefault();    
    return false;
  });
  $(document).on("show.bs.collapse", ".collapse", function(event) {
      // Update the icon
      $(this).parent().find('.collapse-toggle i').removeClass("umlaut_icons-list-closed").addClass("umlaut_icons-list-open");
      // Update the action label
      $(this).parent().find(".expand_contract_action_label").text("Hide ");

  });
  $(document).on("hide.bs.collapse", ".collapse", function(event) {
      // Update the icon
      $(this).parent().find('.collapse-toggle i').removeClass("umlaut_icons-list-open").addClass("umlaut_icons-list-closed");
      // Update the action label
      $(this).parent().find(".expand_contract_action_label").text("Show ");

  });
});

