/* expand_contract_toggle.js: Support for show more/hide more in lists of umlaut content.
*/
jQuery(document).ready(function($) {
  $(".collapse_toggle").each(function(){
    $(this).collapse('toggle');
  });
  $(document).on("click", ".collapse-toggle", function(event) {
    event.preventDefault();    
    return false;
  });
  $(document).on("shown", ".collapse", function(event) {
      // Update the icon
      $(this).parent().find('.collapse-toggle i').removeClass("umlaut_icons-list-closed").addClass("umlaut_icons-list-open");
      // Update the action label
      $(this).parent().find(".expand_contract_action_label").text("Hide ");

  });
  $(document).on("hidden", ".collapse", function(event) {
      // Update the icon
      $(this).parent().find('.collapse-toggle i').removeClass("umlaut_icons-list-open").addClass("umlaut_icons-list-closed");
      // Update the action label
      $(this).parent().find(".expand_contract_action_label").text("Show ");

  });
});
