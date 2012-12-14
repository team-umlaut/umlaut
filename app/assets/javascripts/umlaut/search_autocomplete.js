/* search_autocomplete.js.  Add autocomplete to Umlaut journal title search. */
jQuery(document).ready(function($) {
  $("form.OpenURL").live("submit", function() {
    var form = $(this);
    if ( form.find(".rft_title").val() != $(this).val()) {
      form.find(".rft_object_id").val("");
      form.find(".rft_title").val("");
    }
  });

  // Search for the title with the current form.
  var search_title = function(query, process) {
    var form = this.$element.closest("form");
    var url = form.attr("action").replace("journal_search", "auto_complete_for_journal_title");
    // Get JSON from 
    $.getJSON(
      form.attr("action").replace("journal_search", "auto_complete_for_journal_title"),
      form.serialize(),
      function(data) {
        process(data)
      }
    )
  }

  $("input.title_search").typeahead({
    items: 10,
    minLength: 3,
    source: search_title,
    highlighter: function(item) { 
      // Bootstrap updates the item as it passes through the callback chain
      // so this is a hack to ensure we get the proper values.
      return "<strong id=\"" + item.object_id + "\" class=\"title\">"+ item.title + "</strong>"; 
    },
    sorter: function(items) { return items },
    matcher: function(item) { return true; },
    updater: function(item) {
      // Get the selected item via our hack.
      var selected_item = this.$menu.find('.active .title');
      // We set the id attribute as the object id
      var object_id = selected_item.attr("id");
      // We set the inner text with the title
      var title = selected_item.text();
      var form = this.$element.closest("form");
      form.find("input.rft_object_id").val(object_id);
      form.find("input.rft_title").val(title);
      form.find("select.title_search_type").val("exact");
      return title;
    }
  });
});