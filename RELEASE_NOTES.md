## 4.1

This release is expected to be entirely backwards compatible with 4.0, and
should be an easy upgrade. But testing in a non-production environment
is always advisable. 

We recommend upgrading to Umlaut 4.1, Rails 4.2, and using ruby 2.2.x, as soon
as convenient. Note that ruby 1.9.3 is no longer supported by the ruby project. 

COMPATIBILITY

Rails 4.2 is now supported. Rails down to 3.2.12 is also supported, but
we always suggest keeping your Rails current. http://guides.rubyonrails.org/4_2_release_notes.html

USER INTERFACE

"Search Inside" and "Limited Preview" display sections now appear by
default in the sidebar. This is based on experience at multiple institutions,
but if you'd like to restore them to the center column, it is easily
configurable, see: https://github.com/team-umlaut/umlaut/wiki/Customizing#display-section-configuration

NEW FEATURES

Most new features are focused on adding hooks for additional
configuration and customization. 

* The umlaut_services.yml file is now run through ERB, so you can
  include dynamic ERB code (executed on boot)
* `remove_section` and `insert_section` hooks for changing
  display section order. https://github.com/team-umlaut/umlaut/wiki/Customizing#display-section-configuration
* `add_resolve_sections_filter!` configuration method, for
  per-request customization of resolve display sections. 
  https://github.com/team-umlaut/umlaut/wiki/Customizing#per-request-resolve-section-configuration
* `add_section_highlights_filter!` configuration method, to 
  add per-request logic for determining which display sections receive
  highlight styling. https://github.com/team-umlaut/umlaut/wiki/Customizing#customize-section-highlighting
* JQuery Content Utility adds new js constructor, and support for 'container' restrictions. See https://github.com/team-umlaut/umlaut/wiki/JQuery-Content-Utility#more-than-one-citation-on-a-page
* Umlaut.register_routes method for plugins to add their own routing to Umlaut. 
* Umlaut::TestHelp module with convenience methods for writing tests against umlaut. 

BUG FIXES

* Better description of errors in logs. 
* In some cases background services would be executed before their
properly assigned service wave, and/or executed more than once. This has been fixed. 
* MetadataHelper#normalize_title work properly for non-ascii unicode. 
* MetadataHelper#title_is_serial? more complex logic. 
* Dublin Core format OpenURL doesn't cause an exception anymore (but don't count
  on Umlaut doing anything very useful with it)
* Assorted other minor bug fixes. 



SERVICE-SPECIFIC

* InternetArchive: Require closer title match to count as a hit. 
* SFX: Add boost_targets and sink_targets options to reorder targets. 
* SFX: More conservative referent enhancement, try to avoid bad data. 
* Web of Science and JCR: Optionally support username/password-based auth

## 4.0

Sorry, no release were compiled for this release. I18n coverage hitting most
parts of Umlaut was first added in this release, along with upgrade to
Bootstrap 3 and support for Rails 4. 

## 3.3.0

* New ILLiad service
* New Scopus2 service based on new non-deprecated Scopus API
* New built-in Umlaut user feedback functionality
* Assorted bugfixes

## 3.2.0

* Assorted bugfixes and refactoring

## 3.1.0

* Major visual redesign, based on bootstrap, responsive on small screens	
  * If you have local CSS customizations, you will probably need to redesign and reapply them
  * Check your local app/assets/application.css, REMOVE any references to jquery-ui
    that Umlaut may have added, no longer needed.
  * If you have a local Rails layout, you will probably want to compare to current
  	Umlaut default layout, and redo yours based on that. 
	* Check any local customizations of CSS or visual design before upgrading in production. 
	* Check [Customizing on wiki](https://github.com/team-umlaut/umlaut/wiki/Customizing) for
	  any updated 3.1 relevant instructions. 
  * Check updated wiki page on [Customizing](https://github.com/team-umlaut/umlaut/wiki/Customizing)  Umlaut. 

* New service for linking out to Google scholar search. 

* On-demand permalinks
	* Permalinks only created when asked for by user, with AJAX ui. 
	* Delete the 'permalinks'	line from your config in controller/umlaut_controller.rb,
	  it's no longer effective. 

* Better support for configuring multiple service groups, which can be
  activated or de-activated for any given request. See 
  https://github.com/team-umlaut/umlaut/wiki/Alternate-service-groups

* Reduced default background AJAX poll wait times, for increased apparent
  responsiveness. 

* When upgrading Umlaut and making sure it breaks nothing for you, 
  it would be a good time to run `bundle update` and update all gem
  dependencies in your umlaut app to the latest and greatest. 


## Older

3.0.1 - More tolerant of badly encoded bytes in input OpenURLs, will
        generally replace with unicode replacement char. Should also
        properly interpret incoming OpenURLs in ISO-8859-1 due to 
        upgrade to openurl gem. 
