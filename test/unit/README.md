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
(the responses from those kicked of services).

Since service adaptors handle Requests, in order to test that a service adaptor works
correctly, we need to set up a request that will trigger the service.

Setting up a Request is a bit of a pain, but here are the steps.

1. Create a referent  
   Add a [referent](/team-umlaut/umlaut/blob/master/test/fixtures/referents.yml),
   which can have atitle, title, issn, isbn, year, volume e.g.
   
        coffeemakers:
          atitle: "A blend of different tastes: the language of coffeemakers"
          title: '
          issn: 0265-8135
          year: 1998
          volume: 25

2. Create referent values  
   The meat of your citation will actually be stored as
   [referent values](/team-umlaut/umlaut/blob/master/test/fixtures/referent_values.yml),
   so we need to create those in order to handle pesky details like normalization.
   Referent values can have referent, key\_name, value, normalized\_value,
   metadata (flag), private_data(flag) e.g.
   
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
Once you have your request defined, you can 

