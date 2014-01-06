/*
  load_permalink.js:
    Create the permalink on request
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
  $("*[data-umlaut-toggle-permalink]").click(function (event) {
    var originalLink, valueContainer;
    event.preventDefault();
    originalLink = $(this);
    valueContainer = $("#umlaut-permalink-container");
    if (!valueContainer.data("loaded")) {
      valueContainer.html('<span class="umlaut-permalink-content"><i class="spinner"></i></span>').show();
      $.getJSON(originalLink.attr('href'), function (data) {
        var href, a;
        href = data.permalink;
        a = $("<a class='umlaut-permalink-content'/>");
        a.attr("href", href);
        a.text(href);
        valueContainer.html(a).data("loaded", true).show();
      });
    } else {
      valueContainer.toggle();
    }
  });
});
