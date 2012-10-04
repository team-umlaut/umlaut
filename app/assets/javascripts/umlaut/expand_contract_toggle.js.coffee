# expand_contract_toggle.js: Support for show more/hide more in lists of umlaut content.
# The JS swaps out the icon class for expand/contract toggle, changes the label and shows/hides content.
$ ->
  $(".expand_contract_toggle").live "click", (event)->
      event.preventDefault()
      content = $(this).next ".expand_contract_content"
      icon = $(this).parent().find "i.umlaut-toggle"
      label = $(this).parent().find ".expand_contract_action_label"
      label_text = if content.is ":visible" then "Show " else "Hide "
      icon.toggleClass("icons-list-closed icons-list-open")
      label.text label_text
      content.toggle()
