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

Umlaut is distributed as a ruby Rails engine gem. It's a very heavyweight engine,
the point of distro'ing as a gem is to make it easy to keep local 
config/customization/enhancement seperate from distro, not so much to let you
'mix in' Umlaut to an already existing complex app. 


## Installation

For complete step-by-step install instructions suitable even for the neophyte, see:
https://github.com/team-umlaut/umlaut/wiki/Installation. 

The Rails/Umlaut super-concise expert summary is:

* Rails 3.1+

* gem 'umlaut'

* `bundle install`
    
* `$ rails generate umlaut:install`

* mysql database strongly encouraged, sqlite3 probably won't work. 

* configuration in `./config/umlaut_services.yml` and `./app/controllers/umlaut_controller.rb` 

* Umlaut uses multi-threaded concurrency in a way incompatible with development-mode class reloading. You need cache_classes=false even in dev, the Umlaut install generator changes this for you. 
    
## Source

https://github.com/team-umlaut/umlaut/

## Listserv

You can join the umlaut listserv at:
http://rubyforge.org/mail/?group_id=4382
