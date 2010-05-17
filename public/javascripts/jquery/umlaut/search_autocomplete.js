/* search_autocomplete.js.  Add autocomplete to Umlaut journal title search. */
jQuery(document).ready(function($) {
    
    $("form.OpenURL").live("submit", function() {
       var form = $(this);
       if ( form.find(".rft_title").val() != $(this).val()) {
          form.find(".rft_object_id").val("");
          form.find(".rft_title").val("");
       }
    });
    
  $("input.title_search").autocomplete({
            minLength: 3,
            source: function(request, response) {              
              var form = $(this.element).closest("form");
              $.ajax({
                  url: form.attr("action").replace("journal_search", "auto_complete_for_journal_title"),
                  dataType: "json",
                  data: form.serialize(),
                  success: function(data) {
                    response($.map(data, function(item) {
                      return {
                        label: item.title,
                        id: item.object_id
                      }
                    }));
                  }
              });
            },
            select: function(event, ui) {
              var form = $(event.target).closest("form");
              
              form.find("input.rft_object_id").val(ui.item.id);
              form.find("input.rft_title").val( ui.item.label );
              form.find("select.sfx_title_search").val("exact");
            }
          });
  
});


/*					select: function(event, ui) {
						log(ui.item ? ("Selected: " + ui.item.value + ", geonameId: " + ui.item.id) : "Nothing selected, input was " + this.value);
					}
				});
*/
