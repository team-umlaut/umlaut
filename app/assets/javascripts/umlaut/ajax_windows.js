/* ajax_windows.js.  Support for modal popup windows in Umlaut items. */
jQuery(document).ready(function($) {
  var populate_modal = function(data, textStatus, jqXHR) {
    // Wrap the data object in jquery object
    var body = $("<div/>").html(data);
    // Remove the first heading from the returned data
    var header = body.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
    // Remove the first submit button from the returned data
    var footer = body.find("form").find("input[type=submit]").eq(0).remove();
    cleanup_modal(header, body, footer)
  }
  var cleanup_modal = function() {
    header = arguments[0]
    body = arguments[1]
    footer = arguments[2]
    // Replace the header text if given
    if (header) $("#modal").find(".modal-header").find("[data-role=modal-title-content]").text(header.text());
    // Replace the body html if given
    if (body) $("#modal").find(".modal-body").find("[data-role=modal-body-content]").html(body.html());
    // Replace the current submit button if given
    if (footer) $("#modal").find(".modal-footer").find("[data-role=modal-footer-content]").html(footer);
    // Toggle the ajax-loader
    $("#modal").find(".modal-header").find(".ajax-loader").toggle();
    $("#modal").find(".modal-body").find(".ajax-loader").toggle();
  }
  var display_modal = function(event) {
    event.preventDefault();
    cleanup_modal();
    $("#modal").modal("show");
    $.get(this.href, "", populate_modal, "html");
    return false;
  }
  var ajax_form_catch = function(event) {
    event.preventDefault();
    cleanup_modal();
    var form =  $("#modal").find("form");
    $.post(form.attr("action"), form.serialize(), populate_modal, "html");
    return false;
  };
  $(document).on("click", "a.ajax_window", display_modal);
  $(document).on("click", "#modal .modal-footer input[type=submit]", ajax_form_catch);
  $(document).on("submit", "#modal form", ajax_form_catch);
});