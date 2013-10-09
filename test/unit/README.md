# Testing Service Adaptors

It's not you, testing service adaptors is _confusing_.

Here are some basics to get you started.

## Fixtures
A key component of Umlaut is the
[Request](/team-umlaut/umlaut/blob/master/app/models/request.rb).
Requests tie together
[Referents](/team-umlaut/umlaut/blob/master/app/models/referent.rb) 
(basically, the desired citation), 
[Dispatched Services](/team-umlaut/umlaut/blob/master/app/models/dispatched_service.rb)
(the services that get kicked off), and
[Service Responses](/team-umlaut/umlaut/blob/master/app/models/dispatched_service.rb)
(the responses from those kicked off services).

Since service adaptors handle Requests, in order to test that a service adaptor works
correctly, we need to set up a request that will trigger the service.

Setting up a Request is a bit of a pain, but here are the steps.

1. Create a referent  
   Add a [referent](/team-umlaut/umlaut/blob/master/test/fixtures/referents.yml),
   which can have atitle, title, issn, isbn, year, volume
   
        coffeemakers:
          atitle: "A blend of different tastes: the language of coffeemakers"
          issn: 0265-8135
          year: 1998
          volume: 25

2. Create referent values  
   The meat of your citation will actually be stored as
   [referent values](/team-umlaut/umlaut/blob/master/test/fixtures/referent_values.yml),
   so we need to create those in order to handle pesky details like normalization.
   Referent values can have referent, key\_name, value, normalized\_value,
   metadata (flag), private_data(flag)
   
        coffeemakers1:
          referent: coffeemakers
          key_name: format
          value: journal
          normalized_value: journal
          metadata: false
          private_data: false
          
        coffeemakers2:
          referent: coffeemakers
          key_name: genre
          value: article
          normalized_value: article
          metadata: true
          private_data: false

        coffeemakers3:
          referent: coffeemakers
          key_name: atitle
          value: "A blend of different tastes: the language of coffeemakers"
          normalized_value: "a blend of different tastes: the language of coffeemakers"
          metadata: true
          private_data: false

        coffeemakers4:
          referent: coffeemakers
          key_name: issn
          value: "0265-8135"
          normalized_value: "0265-8135"
          metadata: true
          private_data: false

        coffeemakers5:
          referent: coffeemakers
          key_name: volume
          value: 25
          normalized_value: 25
          metadata: true
          private_data: false

3. Create the request  
   Add an entry in the
   [requests fixture YAML](/team-umlaut/umlaut/blob/master/test/fixtures/requests.yml)
   and point it to the referent you just set up.
   
        coffeemakers:
          referent: coffeemakers
## Writing Your Tests
Once you have your request defined, you can test your service.

Assuming you've read the 
[wiki section on testing](https://github.com/team-umlaut/umlaut/wiki/Developing#automated-testing),
first you'll need to create a new service.
The best way to do this is to pass a config Hash into the `new` method

    bx_token = ENV['BX_TOKEN'] || 'BX_TOKEN'
    config = { 
      "service_id" => "Bx", 
      "priority" => "1",
      "token" => bx_token
    }
    @bx_service_adaptor = Bx.new(config)

__Please note__ that `service_id` and `priority` are required by Umlaut.

Then you'll want to get your request fixture and call the `handle` method on
your service adaptor

    # Get the relevant request fixture
    coffeemakers_request = requests(:coffeemakers)

    @bx_service_adaptor.handle(coffeemakers_request)

After calling handle, you'll want to see if you got any responses back from your
service adaptor.  Make sure to go back to the database to get the latest

    # Refresh with the latest from the DB after handling the service.
    coffeemakers_request.dispatched_services.reset
    coffeemakers_request.service_responses.reset

    # Get the returned 'similar' service responses
    similars = coffeemakers_request.get_service_type('similar')

And then test some stuff

    # There should be 5 'similar' service responses
    assert_equal(5, similars.length, "Ack. Similar responses have gone awry!")
