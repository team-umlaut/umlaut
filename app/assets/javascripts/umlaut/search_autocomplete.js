/*
  search_autocomplete.js:
    Add autocomplete to Umlaut journal title search.
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
  var newRender, searchTitle, lookupLimit, throttledSearchTitle;
  // We override typeahead's 'render' function to NOT have the first
  // item selected. We simply copy and pasted it, and removed the line
  // `items.first().addClass('active')`, then set the prototype to our
  // own function. Yes, this changes typeahead globally, sorry we don't have
  // a way to change it just for certain typeaheads.
  //
  // The default first-item-selected behavior has been hated by users
  // in the journal search scenario, since when they hit return they
  // get it even if they didn't want it.
  newRender = function (items) {
    var that = this;
    items = $(items).map(function (i, item) {
      i = $(that.options.item).attr('data-value', item);
      i.find('a').html(that.highlighter(item));
      return i[0];
    });
    this.$menu.html(items);
    return this;
  };
  $.fn.typeahead.Constructor.prototype.render = newRender;
  // have to fix 'select' to accomodate possible no selection too
  $.fn.typeahead.Constructor.prototype.select = function () {
    var val = this.$menu.find('.active').attr('data-value');
    if (val) {
      this.$element.val(this.updater(val)).change();
    }
    return this.hide();
  };

  $(document).on("submit", "form.OpenURL", function () {
    var form = $(this);
    if (form.find(".rft_title").val() !== $(this).val()) {
      form.find(".rft_object_id").val("");
      form.find(".rft_title").val("");
    }
  });

  // Search for the title with the current form. Only search
  // if there are more than two chars though!
  //
  searchTitle = function (query, process) {
    var form;
    if (query.length > 2) {
      form = this.$element.closest("form");
      form.attr("action").replace("journal_search", "auto_complete_for_journal_title");
      // Get JSON from
      $.getJSON(
        form.attr("action").replace("journal_search", "auto_complete_for_journal_title"),
        form.serialize(),
        function (data) {
          process(data);
        }
      );
    }
  };

  lookupLimit = 300; //ms
  // Uses a timer to only do a lookup at most once every
  // 300ms . Based on rejected pull request at:
  // https://github.com/twitter/bootstrap/pull/6320
  throttledSearchTitle = function (query, process) {
    if (this.lookupTimer) {
      clearTimeout(this.lookupTimer);
    }
    this.lookupTimer = setTimeout($.proxy(searchTitle, this, query, process), lookupLimit);
    return this;
  };

  $("input.title_search").typeahead({
    items: 10,
    minLength: 3,
    source: throttledSearchTitle,
    highlighter: function (item) {
      // Bootstrap updates the item as it passes through the callback chain
      // so this is a hack to ensure we get the proper values.
      return "<span id=\"" + item.object_id + "\" class=\"title\">" + item.title + "</span>";
    },
    sorter: function (items) { return items; },
    matcher: function () { return true; },
    updater: function () {
      var selectedItem, objectId, title, form;
      // Get the selected item via our hack.
      selectedItem = this.$menu.find('.active .title');
      if (selectedItem.length > 0) {
        // We set the id attribute as the object id
        objectId = selectedItem.attr("id");
        // We set the inner text with the title
        title = selectedItem.text();
        form = this.$element.closest("form");
        form.find("input.rft_object_id").val(objectId);
        form.find("input.rft_title").val(title);
        form.find("select.title_search_type").val("exact");
        return title;
      }
    }
  });
});
