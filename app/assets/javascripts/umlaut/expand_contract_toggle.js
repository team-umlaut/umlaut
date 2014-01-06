/*
  expand_contract_toggle.js: 
    Support for show more/hide more in lists of umlaut content.

    Expand/collapse elements are already controlled via Bootstrap toggle,
    this just adds some additional behavior in hooks to change our labels
    and disclosure icons appropriately, and prevent following non-js href links. 
*/
/*
  Checked via jslint with the proceding configuration
*/
/*jslint browser: true*/
/*jslint sloppy: true*/
/*jslint passfail: false*/
/*jslint regexp: true*/
/*jslint plusplus: true*/
/*jslint indent: 2*/
/*global jQuery*/
jQuery(document).ready(function ($) {
  $(document).on("click", ".collapse-toggle", function (event) {
    event.preventDefault();    
    return false;
  });
  $(document).on("show", ".collapse", function (event) {
      // Update the icon
      $(this).parent().find('.collapse-toggle i').removeClass("umlaut_icons-list-closed").addClass("umlaut_icons-list-open");
      // Update the action label
      $(this).parent().find(".expand_contract_action_label").text("Hide ");
  });
  $(document).on("hide", ".collapse", function (event) {
      // Update the icon
      $(this).parent().find('.collapse-toggle i').removeClass("umlaut_icons-list-open").addClass("umlaut_icons-list-closed");
      // Update the action label
      $(this).parent().find(".expand_contract_action_label").text("Show ");
  });
});
