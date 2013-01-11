require 'test_helper'
require 'fileutils'
class PrimoSourceTest < ActiveSupport::TestCase
  extend TestWithCassette
  fixtures :requests, :referents, :referent_values, :sfx_urls

  setup do
    @primo_service_definition = YAML.load(%{
      type: PrimoService
      priority: 2 # After SFX, to get SFX metadata enhancement
      status: active
      base_url: http://bobcat.library.nyu.edu
      vid: NYU
      institution: NYU
      suppress_holdings: [ !ruby/regexp '/\$\$LBWEB/', !ruby/regexp '/\$\$LNWEB/', !ruby/regexp '/\$\$LTWEB/', !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
      ez_proxy: https://ezproxy.library.nyu.edu/login?url=
      service_types:
        - primo_source })
    @primo_source_defintion = YAML.load(%{
      type: PrimoSource
      priority: 3 # After PrimoService, to get store Primo sources.
      status: active
      base_url: http://bobcat.library.nyu.edu
      vid: NYU
      institution: NYU })
    @primo_service = ServiceStore.instantiate_service!(@primo_service_definition)
    @primo_source = ServiceStore.instantiate_service!(@primo_source_definition)
  end

  test "new" do
    assert_nothing_raised {
      primo_source = PrimoSource.new(@primo_source_definition)
    }
  end

  test_with_cassette("primo source handle", :primo) do
    request = requests(:primo_id_request)
    @primo_service.handle(request)
    request.dispatched_services.reset
    request.service_responses.reset
    @primo_source.handle(request)
  end
end