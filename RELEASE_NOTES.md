## 3.1.0

* Major visual redesign, based on bootstrap, responsive on small screens	
  * If you have local CSS customizations, you will probably need to redesign and reapply them
  * If you have a local Rails layout, you will probably want to compare to current
  	Umlaut default layout, and redo yours based on that. 
	* Check any local customizations of CSS or visual design before upgrading in production. 
	* Check [Customizing on wiki](https://github.com/team-umlaut/umlaut/wiki/Customizing) for
	  any updated 3.1 relevant instructions. 

* New service for linking out to Google scholar search. 

* On-demand permalinks
	* Permalinks only created when asked for by user, with AJAX ui. 
	* Delete the 'permalinks'	line from your config in controller/umlaut_controller.rb,
	  it's no longer effective. 

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
