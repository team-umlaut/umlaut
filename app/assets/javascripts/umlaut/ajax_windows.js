/* 
  ajax_windows.js:
    Support for modal popup windows in Umlaut items.
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
  var populateModal, cleanupModal, displayModal, ajaxFormCatch;
  populateModal = function (data) {
    var header, body, footer;
    // Wrap the data object in jquery object
    body = $(data);
    // Remove the first heading from the returned data
    header = body.find("h1, h2, h3, h4, h5, h6").eq(0).remove();
    // Remove the first submit button from the returned data
    footer = body.find("form").find("input[type=submit]").eq(0).remove();
    cleanupModal(header, body, footer);
  };
  cleanupModal = function (header, body, footer) {
    // Replace the header text if given
    if (header) {
      $("#modal").find(".modal-header").find(".content").text(header.text());
    }
    // Replace the body html if given
    if (body) {
      $("#modal").find(".modal-body").find(".content").html(body.html());
    }
    // Replace the current submit button if given
    if (footer) {
      $("#modal").find(".modal-footer").find(".content").html(footer);
    }
    // Toggle the ajax-loader
    $("#modal").find(".modal-header").find(".ajax-loader").toggle();
    $("#modal").find(".modal-body").find(".ajax-loader").toggle();
    // Toggle the content
    $("#modal").find(".modal-header").find(".content").toggle();
    $("#modal").find(".modal-body").find(".content").toggle();
    $("#modal").find(".modal-footer").find(".content").toggle();
  };
  displayModal = function (event) {
    event.preventDefault();
    cleanupModal();
    $("#modal").modal("show");
    $.get(this.href, "", populateModal, "html");
    return false;
  };
  ajaxFormCatch = function (event) {
    var form;
    event.preventDefault();
    cleanupModal();
    form = $("#modal").find("form");
    $.post(form.attr("action"), form.serialize(), populateModal, "html");
    return false;
  };
  $(document).on("click", "a.ajax_window", displayModal);
  $(document).on("click", "#modal .modal-footer input[type=submit]", ajaxFormCatch);
  $(document).on("submit", "#modal form", ajaxFormCatch);
});
