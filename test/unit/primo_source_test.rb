require 'test_helper'
require 'fileutils'
class PrimoSourceTest < ActiveSupport::TestCase
  extend TestWithCassette
  fixtures :requests, :referents, :referent_values, :sfx_urls

  setup do
    @primo_service_definition = YAML.load(%{
      service_id: Primo
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
    @primo_source_definition = YAML.load(%{
      service_id: PrimoSource
      type: PrimoSource
      priority: 3 # After PrimoService, to get store Primo sources.
      status: active
      base_url: http://bobcat.library.nyu.edu
      vid: NYU
      institution: NYU })
    @primo_service = ServiceStore.instantiate_service!(@primo_service_definition, nil)
    @primo_source = ServiceStore.instantiate_service!(@primo_source_definition, nil)
  end

  test "new" do
    assert_nothing_raised {
      primo_source = PrimoSource.new(@primo_source_definition)
    }
  end

  test_with_cassette("primo source handle", :primo) do
    assert_nothing_raised {
      request = requests(:primo_id_request)
      @primo_service.handle(request)
      request.dispatched_services.reload
      request.service_responses.reload
      @primo_source.handle(request)
      request.dispatched_services.reload
      request.service_responses.reload
      holdings = request.get_service_type('holding', {:refresh => true})
      assert_equal(1, holdings.size)
      holdings.each do |holding|
        view_data = holding.view_data
        assert((not view_data[:source_data].nil?), "Book :source_data is nil.")
        assert((not view_data[:source_data].empty?), "Book :source_data is empty.")
        assert_equal("NYU01", view_data[:source_data][:doc_library], "Book :source_data[:doc_library] is unexpected.")
      end
    }
  end

  test_with_cassette("primo journal issn search handle", :primo) do
    assert_nothing_raised {
      request = requests(:primo_journal1_request)
      @primo_service.handle(request)
      request.dispatched_services.reload
      request.service_responses.reload
      holdings = request.get_service_type('holding', {:refresh => true})
      assert_equal(0, holdings.size)
      @primo_source.handle(request)
      request.dispatched_services.reload
      request.service_responses.reload
      holdings = request.get_service_type('holding', {:refresh => true})
      assert_equal(5, holdings.size)
      holdings.each do |holding|
        view_data = holding.view_data
        assert((not view_data[:source_data].nil?), "Journal :source_data is nil.")
        assert((not view_data[:source_data].empty?), "Journal :source_data is empty.")
        assert_equal("NYU01", view_data[:source_data][:doc_library], "Journal :source_data[:doc_library] is unexpected.")
      end
    }
  end
end