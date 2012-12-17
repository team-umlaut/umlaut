#Testing Umlaut

Testing coverage in Umlaut is not yet comprehensive, but is continually improving.  
There is more about this topic on the [Umlaut Wiki](https://github.com/team-umlaut/umlaut/wiki/Developing)

##Testing Principles

When writing tests for Umlaut, there are a few things you should keep in mind.

### Dummy app

We used rails 3.1 `rails plugin new` generator to create a gem plugin skeleton for Umlaut. 
One thing this did was create a `./test/dummy` dummy app in umlaut source. 
This is meant for running tests against. Tests you write in `/test/*` will run against the dummy app. 
The dummy app can have configuration customized (with those changes committed) if needed to exercise certain features 
(although changing config 'live' and temporarily in a test itself would be preferable where feasible). 
The dummy app doesn't have a `database.yml`, you'll need to add one pointing at a local mysql 
(not sqlite3, umlaut won't work against sqlite3). 

### Test::Unit/Minitest please

Please use straight Test::Unit and/or Minitest.  Please do not use rspec, cucumber, etc. Put tests in `./test`.  There's already a `rake test` to run all tests.

### Tests should pass locally for everyone

Tests should pass for everyone with a straight umlaut checkout without modifying any files but adding a database.yml. 

Please don't add tests that raise or fail without a private API key or access to a private server. 
We've started to use the [VCR](https://github.com/myronmarston/vcr) gem to record HTTP responses to provide deterministic testing results.
VCR "cassettes" are committed to the repo in `./test/vcr_cassettes/<module>`.
To run VCR tests, you can leverage the `TestWithCassette` support module following the example below.

    class GoogleBookSearchTest < ActiveSupport::TestCase  
      extend TestWithCassette

      # Use VCR to provide a deterministic GBS search. 
      test_with_cassette("frankenstein by OCLC number", :google_book_search) do
        hashified_response = @gbs_default.do_query('OCLC2364071', requests(:frankenstein))
        assert_not_nil hashified_response
        assert_not_nil hashified_response["totalItems"]
        assert_operator hashified_response["totalItems"], :>, 0 
      end
    end
    
We still want to figure out a way for someone with access to the necessary third party platforms to 
choose to run against 'live' too (for only specified services?) 
(and then commit the new versions of the responses back to repo if they want). 
There's some stuff to figure out, yeah.

If you really must write tests that require private api keys or access to private servers to pass, 
then I guess that's better than no tests at all, but figure out a way to:

* Clearly document where the developer should put those private api keys or local server URLs to get tests to pass. 
* Keep from interfering with running the rest of the test suite for a developer who does not have that private information filled out. 
  Ideally tests that require it would output a clear 'skipped' or 'pending' message 
  (explaining what needs to be configured to run them_ rather than failing.)
  **In no cases should they raise exceptions in such a way that prevents the rest of the test suite from continuing.**

### Test should pass on Travis, too

[Travis](http://travis-ci.org) is a continuous integration service for the open source community that Umlaut leverages to run tests.
One reason to use Test::Unit/Minitest is that [Travis](https://travis-ci.org/#!/team-umlaut/umlaut) will automatically run your tests.

Travis creates the necessary MySQL databases and runs tests against the dummy app based on the database configuration in
`./test/dummy/config/travis_database.yml`.

One specific test Travis runs is for SFX search functionality.  
Travis uses the configuration in `./test/dummy/config/travis_database.yml` to create a mock instance of an 
SFX global and local database, migrates the SFX database schema and the test populates the database with 
deterministic SFX Object and AZ Title fixtures.  
It tests basic search functionality and serves as a sanity check to make sure SFX searching is working as expected.
This test make @jrochkind very nervous, and **you probably shouldn't ever run this test locally**.  The migrations and test code
only run in the case that the SFX database configuration is specified as a 'mock instance' in order to prevent overwriting
a real SFX database. (Yet another reason the Umlaut user that queries SFX should only have read permissions.)

