/* ajax_windows.js.  Support for modal popup windows in Umlaut items. */
jQuery(document).ready(function($) {
  var populate_modal = function(data, textStatus, jqXHR) {
    // Wrap the data object in jquery object
    var body = $("<div/>").html(data);
    // Remove the first heading from the returned data
    var header = body.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
    // Remove the first submit button from the returned data
    var footer = body.find("form").find("input[type=submit]").eq(0).remove();
    
    // Add in content
    if (header) $("#modal").find("[data-role=modal-title-content]").text(header.text());    
    if (body) $("#modal").find("[data-role=modal-body-content]").html(body.html());    
    if (footer) $("#modal").find("[data-role=modal-footer-content]").html(footer);
    // Toggle the ajax-loader
    $("#modal").find(".ajax-loader").hide();
  }
  var cleanup_modal = function() {
    $("#modal").find("[data-role=modal-title-content]").text('');
    $("#modal").find("[data-role=modal-body-content]").text('');
    $("#modal").find("[data-role=modal-footer-content]").text('');
    $("#modal").find(".ajax-loader").hide();
  }
  var display_modal = function(event) {
    event.preventDefault();
    cleanup_modal();
    $("#modal").find(".ajax-loader").show();
    $("#modal").modal("show");
    $.get(this.href, "", populate_modal, "html");
  }
  var ajax_form_catch = function(event) {
    event.preventDefault();
    $("#modal").find(".ajax-loader").show();
    var form =  $("#modal").find("form");
    $.post(form.attr("action"), form.serialize(), populate_modal, "html");
    cleanup_modal();
  };
  $(document).on("click", "a.ajax_window", display_modal);
  $(document).on("click", "#modal .modal-footer input[type=submit]", ajax_form_catch);
  $(document).on("submit", "#modal form", ajax_form_catch);
});