# Umlaut
[![Gem Version](https://badge.fury.io/rb/umlaut.png)](http://badge.fury.io/rb/umlaut)
[![Build Status](https://secure.travis-ci.org/team-umlaut/umlaut.png)](http://travis-ci.org/team-umlaut/umlaut)
[![Dependency Status](https://gemnasium.com/team-umlaut/umlaut.png)](https://gemnasium.com/team-umlaut/umlaut)
[![Code Climate](https://codeclimate.com/github/team-umlaut/umlaut.png)](https://codeclimate.com/github/team-umlaut/umlaut)
[![Coverage Status](https://coveralls.io/repos/team-umlaut/umlaut/badge.png?branch=master)](https://coveralls.io/r/team-umlaut/umlaut)
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

[What do you mean by all this?](https://github.com/team-umlaut/umlaut/wiki/What-is-Umlaut-anyway%3F)

Umlaut is distributed as a ruby Rails engine gem. It's a very heavyweight engine,
the point of distro'ing as a gem is to make it easy to keep local 
config/customization/enhancement seperate from distro, not so much to let you
'mix in' Umlaut to an already existing complex app. 


## Installation

For complete step-by-step install instructions suitable even for the neophyte, see:
https://github.com/team-umlaut/umlaut/wiki/Installation. 

The Rails/Umlaut super-concise expert summary is:

* Rails 3.2+ (Rails 4.1+ highly recommended, Rails 3's days are numbered), 
* ruby 1.9.3+ (Consider ruby 2.0 or 2.1, 1.9.3's days are numbered)

* `$ gem install umlaut`
* Then run the umlaut app generator:  `$ umlaut my_new_app`
  * That will make a new rails app
  * without spring or turbolinks
  * using mysql (sqlite3 does not work for umlaut)
  * it will add the umlaut gem to your app
  * and it will run umlaut's generator to add a couple more files to your app, equivalent of `$ rails generate umlaut:install`

* set up your db in config/databases.yml and run `rake db:migrate`
* configuration in `./config/umlaut_services.yml` and `./app/controllers/umlaut_controller.rb` 

* Umlaut uses multi-threaded concurrency in a way incompatible with development-mode class reloading. You need cache_classes=false even in dev, the Umlaut install generator changes this for you.

## Add ons
Some Umlaut services adapters are sufficiently complicated or are on different release cycles 
from the core code that they merit their own gems. Generally, you will need to include these gems 
in your application's Gemfile in order to get the described functionality.

| Add on | Description |
|:---|:---|
| [`umlaut-primo`](https://github.com/team-umlaut/umlaut-primo) | Umlaut services to provide full text service responses, holdings, etc. from the Primo discovery solution. |


## Developing

Some test coverage not yet complete, but we're trying to improve. Don't trust
if all tests pass everythings good, but if tests fail, that's an unacceptable
commit. Try to add tests with new features, although we understand when
nobody can figure out a good way to test (esp our legacy architecture). 

Run tests with `rake test`. 

Tests are with plain old Test::Unit, please. 

Tests use the vcr gem where appropriate. See `./test/support/test_with_cassette`.

gem skeleton was created with `rails plugin new`, which creates a dummy app
that tests are run in context of, at `./test/dummy`. 

The vcr gem is used to record HTTP transactions for tests. 

There are some helpful methods for setting up and asserting in tests in
Umlaut::TestHelp, which are used in Umlaut itself and can also be used
in local apps or Umlaut plugins. 

See also: https://github.com/team-umlaut/umlaut/wiki/Developing

## Source

https://github.com/team-umlaut/umlaut/

## Listserv

You can join the umlaut listserv at:
https://groups.google.com/forum/#!forum/umlaut-software
