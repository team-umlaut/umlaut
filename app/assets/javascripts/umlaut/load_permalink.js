jQuery(document).ready(function($) {


	$("*[data-umlaut-toggle-permalink]").click(function(event) {
		event.preventDefault();

		var originalLink   = $(this)
		var valueContainer = $("#umlaut-permalink-container");

		if (! valueContainer.data("loaded")) {
			valueContainer.html('<span class="umlaut-permalink-content"><i class="spinner"></i></span>').show();

			$.getJSON( originalLink.attr('href'), function(data) {
				var href = data.permalink;
				var a = $("<a class='umlaut-permalink-content'/>");
				a.attr("href", href);
				a.text(href);
				valueContainer.html(a).data("loaded", true).show();
			});
		}
		else {
			valueContainer.toggle();
		}
	});

});
