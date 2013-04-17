jQuery(document).ready(function($) {


	$("*[data-umlaut-toggle-permalink]").click(function(event) {
		event.preventDefault();

		var originalLink   = $(this)
		var valueContainer = $("#umlaut-permalink-value");

		if (! valueContainer.data("loaded")) {
			valueContainer.html('<i class="stpinner"></i>').show();

			$.getJSON( originalLink.attr('href'), function(data) {
				var href = data.permalink;
				var a = $("<a/>");
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