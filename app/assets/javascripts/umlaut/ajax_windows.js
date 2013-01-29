/* ajax_windows.js.  Support for modal popup windows in Umlaut items. */
jQuery(document).ready(function($) {
  var populate_modal = function(data, textStatus, jqXHR) {
    data = $(data);
    var heading = data.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
    if (heading) $("#modal .modal-header h3").text(heading.text());
    var submit = data.find("form input[type=submit]").eq(0).remove();
    $("#modal .modal-body").html(data.html());
    $("#modal .modal-footer input[type=submit]").remove();
    if (submit) $("#modal .modal-footer").prepend(submit);
    $("#modal").modal("show");
  }
  var display_modal = function(event) {
    $('body').modalmanager('loading');
    event.preventDefault();
    $.get(this.href, "", populate_modal, "html");
    return false;
  }
  var ajax_form_catch = function(event) {
    event.preventDefault();
    var form =  $("#modal form");
    $.post(form.attr("action"), form.serialize(), populate_modal, "html");
    return false;
  };
  $("a.ajax_window").live("click", display_modal);
  $("#modal .modal-footer input[type=submit]").live("click", ajax_form_catch);
  $("#modal form").live("submit", ajax_form_catch);
});