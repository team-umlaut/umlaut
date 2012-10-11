/* ajax_windows.js.  Support for modal popup windows in Umlaut items. */
jQuery(document).ready(function($) {
  var ajax_form_catch, shared_modal_d;
  shared_modal_d = $("<div></div>").dialog({
    autoOpen: false,
    modal: true,
    width: "400px"
  });
  $("a.ajax_window").live("click", function(event) {
    $(shared_modal_d).load(this.href, function() {
      var heading;
      heading = shared_modal_d.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
      $(shared_modal_d).dialog("option", "title", heading.text());
      return $(shared_modal_d).dialog("open");
    });
    return false;
  });
  ajax_form_catch = function(event) {
    $(shared_modal_d).load($(event.target).closest("form").attr("action"), $(event.target).closest("form").serialize(), function() {
      var heading;
      heading = shared_modal_d.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
      $(shared_modal_d).dialog("option", "title", heading.text());
      return $(shared_modal_d).dialog("open");
    });
    return false;
  };
  $("form.modal_dialog_form input[type=submit]").live("click", ajax_form_catch);
  return $("form.modal_dialog_form").live("submit", ajax_form_catch);
});