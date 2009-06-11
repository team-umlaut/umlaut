/* Holding off on full unobtrusive js for now, onclick is set directly 
   in html. To deal with bg updates need to think how to do it with pure
   unobtrusive. */
/*Event.observe(window, 'load', function() {
    $$('a.expand_contract_toggle').each( function(toggle){
        toggle.onclick = ult_expand_contract_toggle;
    });
});*/


function ult_expand_contract_toggle(element) {
  //element = this;  
  
  label = $(element).down('.expand_contract_action_label');
  content =
    $(element).up('.expand_contract_section').down('.expand_contract_content');
  icon = $(element).down('img.toggle_icon');

  if (content.visible()) {
    if (icon) icon.src = icon.src.replace("list_open.png", "list_closed.png"); 
    if (label) label.update('Show ');
    content.hide();

  }
  else {
    if (icon) icon.src = icon.src.replace("list_closed.png", "list_open.png");            
    if (label) label.update('Hide ');
    content.show();
  }
  
  return false; 
}                

