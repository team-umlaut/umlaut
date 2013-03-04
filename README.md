# Umlaut
[![Build Status](https://secure.travis-ci.org/team-umlaut/umlaut.png)](http://travis-ci.org/team-umlaut/umlaut)
[![Dependency Status](https://gemnasium.com/team-umlaut/umlaut.png)](https://gemnasium.com/team-umlaut/umlaut)
[![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/team-umlaut/umlaut)
<!--[![Security Status](http://rails-brakeman.com/team-umlaut/umlaut.png)](http://rails-brakeman.com/team-umlaut/umlaut)-->

Umlaut is software for libraries (the kind with books). 

It could be described as a front-end layer on top of an existing OpenURL 
knowledge base. But it's actually quite a bit more than that. 

It could also be described as: a just-in-time aggregator of  "last mile" 
specific-citation services, taking input as OpenURL, and providing both an 
HTML UI and an api suite for embedding Umlaut services in other products. 

Umlaut's role is to provide the user with services that apply to the item of interest. 
And services provided by various different products: including as a major target, your
[OpenURL Knowledge Base](http://en.wikipedia.org/wiki/OpenURL_knowledge_base), but also
including other products. Services provided by the hosting institution, licensed by the 
hosting institution, as well as free services the hosting institution wishes to 
advertise/recommend to it's users.

Umlaut strives to supply links that take the user in as few clicks as possible to the service listed, without ever listing 'blind links' that you first have to click on to find out whether they are available. Umlaut pre-checks things when neccesary to only list services, with any needed contextual info, such that the user knows what they get when they click on it. Save the time of the user.

[What do you mean by all this?](https://github.com/team-umlaut/umlaut/wiki/What-is-Umlaut-anyway)

Umlaut is distributed as a ruby Rails engine gem. It's a very heavyweight engine,
the point of distro'ing as a gem is to make it easy to keep local 
config/customization/enhancement seperate from distro, not so much to let you
'mix in' Umlaut to an already existing complex app. 


## Installation

For complete step-by-step install instructions suitable even for the neophyte, see:
https://github.com/team-umlaut/umlaut/wiki/Installation. 

The Rails/Umlaut super-concise expert summary is:

* Rails 3.1+ (but not yet tested with Rails 4), ruby 1.9.3. 

* gem 'umlaut'

* `bundle install`
    
* `$ rails generate umlaut:install`

* mysql database strongly encouraged, sqlite3 probably won't work. 

* configuration in `./config/umlaut_services.yml` and `./app/controllers/umlaut_controller.rb` 

* Umlaut uses multi-threaded concurrency in a way incompatible with development-mode class reloading. You need cache_classes=false even in dev, the Umlaut install generator changes this for you. 

## Developing

Only spotty test coverage, sorry, but we're trying to improve. Don't trust
if all tests pass everythings good, but if tests fail, that's an unacceptable
commit. Try to add tests with new features, although we understand when
nobody can figure out a good way to test (esp our legacy architecture). 

Run tests with `rake test`. 

Tests are with plain old Test::Unit, please. 

Tests use the vcr gem where appropriate. See `./test/support/test_with_cassette`.

gem skeleton was created with `rails plugin new`, which creates a dummy app
that tests are run in context of, at `./test/dummy`. 

See also: https://github.com/team-umlaut/umlaut/wiki/Developing

## Source

https://github.com/team-umlaut/umlaut/

## Listserv

You can join the umlaut listserv at:
http://rubyforge.org/mail/?group_id=4382

