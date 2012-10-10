Sfx4Solr
---
This searcher module leverages [Sunspot](http://sunspot.github.com/) to index SFX AZ Titles in Solr.

In order to use this module, you first need to set up Sunspot in your applications by adding the sunspot_rails
gem to you Gemfile

    gem 'sunspot_rails'

and requiring sunspot_rails in your config/application.rb under umlaut

    require "umlaut"
    require "sunspot_rails"
    
Then run

    $ bundle install
    $ rails generate sunspot_rails:install
    
This will create a file config/sunspot.yml.  You can configure the information about your Solr instance here.
If you don't feel like running your own solr instance, [Websolr](http://websolr.com/) has built in Sunspot support.

You'll also need to specify your SFX4 DBs in your databases.yml. The configuration names are different from the Sfx4
SearchMethod in order to avoid (promote?) ambiguity and confusion.

    sfx4_global:
      adapter: mysql2
      host: sfx.library.edu
      port: 3310
      database: sfxglb41
      username: 
      password: 
      pool: 30
      encoding: utf8

    sfx4_local:
      adapter: mysql2
      host: sfx.library.edu
      port: 3310
      database: sfxlcl41
      username: 
      password: 
      pool: 30
      encoding: utf8

Once your Solr instance is configured and started, run

    $ rake sunspot:reindex
    
to index the AZ titles in Solr. This reindex should probably be run periodically and coincide with SFX KB updates.

After the reindex is complete, add this to your UmlautController search config
    
     az_search_method  SearchMethods::Sfx4Solr::Local
     
and you should be up and running with SFX indexed in Solr.

