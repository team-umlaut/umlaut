/* search_autocomplete.js.  Add autocomplete to Umlaut journal title search. */
jQuery(document).ready(function($) {


 // We override typeahead's 'render' function to NOT have the first
 // item selected. We simply copy and pasted it, and removed the line
 // `items.first().addClass('active')`, then set the prototype to our
 // own function. Yes, this changes typeahead globally, sorry we don't have
 // a way to change it just for certain typeaheads. 
 //
 // The default first-item-selected behavior has been hated by users
 // in the journal search scenario, since when they hit return they
 // get it even if they didn't want it. 
 var newRender = function(items) {
      var that = this

      items = $(items).map(function (i, item) {
        i = $(that.options.item).attr('data-value', item)
        i.find('a').html(that.highlighter(item))
        return i[0]
      })

      this.$menu.html(items)
      return this
 };
 $.fn.typeahead.Constructor.prototype.render = newRender;
 // have to fix 'select' to accomodate possible no selection too
 $.fn.typeahead.Constructor.prototype.select = function() {
    var val = this.$menu.find('.active').attr('data-value');
    if (val) {
      this.$element
        .val(this.updater(val))
        .change();
    }
    return this.hide()
 }

  $(document).on("submit", "form.OpenURL", function() {
    var form = $(this);
    if ( form.find(".rft_title").val() != $(this).val()) {
      form.find(".rft_object_id").val("");
      form.find(".rft_title").val("");
    }
  });

  // Search for the title with the current form. Only search
  // if there are more than two chars though!
  //
  var search_title = function(query, process) {
    if (query.length > 2) {
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
  }


  var lookup_limit = 300; //ms 
  // Uses a timer to only do a lookup at most once every
  // 300ms . Based on rejected pull request at:
  // https://github.com/twitter/bootstrap/pull/6320
  var throttled_search_title = function(query, process) {
    if(this.lookupTimer) {
      clearTimeout(this.lookupTimer);
    }

    this.lookupTimer = setTimeout($.proxy(search_title, this, query, process), lookup_limit);
    return this;
  }

  $("input.title_search").typeahead({
    items: 10,
    minLength: 3,
    source: throttled_search_title,
    highlighter: function(item) { 
      // Bootstrap updates the item as it passes through the callback chain
      // so this is a hack to ensure we get the proper values.
      return "<span id=\"" + item.object_id + "\" class=\"title\">"+ item.title + "</span>"; 
    },
    sorter: function(items) { return items },
    matcher: function(item) { return true; },
    updater: function(item) {
      // Get the selected item via our hack.
      var selected_item = this.$menu.find('.active .title');  
      if (selected_item.length > 0) {
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
    }
  });
});