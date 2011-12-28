# Umlaut

This is Umlaut 3.0.0 _alpha_ software. Umlaut 3.0 is not yet in final release. 
(For Umlaut 2.0, see http://wiki.code4lib.org/index.php/Umlaut . However, if 
you are just getting started checking out Umlaut, you probably should just
start here with 3.0 even though it's alpha). 

Umlaut is software for libraries (the kind with books). 

It could be described as a front-end layer on top of an existing OpenURL 
knowledge base. But it's actually quite a bit more than that. 

It could also be described as: a just-in-time aggregator of  "last mile" 
specific-citation services, taking input as OpenURL, and providing both an 
HTML UI and an api suite for embedding Umlaut services in other products. 


## Installation

For installation instructions suitable for the neophyte, see 
https://github.com/team-umlaut/umlaut/wiki/Installation. 

The Rails expert super concise summary is:

* Rails 3.1+

* gem 'umlaut'

* `bundle install`
    
* `$ rails generate umlaut:install`

* mysql database strongly encouraged, sqlite3 probably won't work. 

* configuration in `./config/umlaut_services.yml` and `./app/controllers/umlaut_controller.rb` 
    
## Source

https://github.com/team-umlaut/umlaut/

## Listserv

You can join the umlaut listserv at:
http://rubyforge.org/mail/?group_id=4382
