require 'test_helper'
require 'fileutils'
class PrimoServiceTest < ActiveSupport::TestCase
  extend TestWithCassette
  fixtures :requests, :referents, :referent_values, :sfx_urls

  def setup
    @primo_definition = YAML.load( %{
        type: PrimoService
        priority: 2 # After SFX, to get SFX metadata enhancement
        status: active
        base_url: http://bobcat.library.nyu.edu
        vid: NYU
        institution: NYU
        holding_search_institution: NYU
        holding_search_text: Search for this title in BobCat.
        suppress_holdings: [ !ruby/regexp '/\$\$LBWEB/', !ruby/regexp '/\$\$LNWEB/', !ruby/regexp '/\$\$LTWEB/', !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
        ez_proxy: https://ezproxy.library.nyu.edu/login?url=
        service_types:
          - primo_source
          - holding_search
          - fulltext
          - table_of_contents
          - referent_enhance
          - cover_image
      })

    @base_url = @primo_definition["base_url"]
    @vid = @primo_definition["vid"]
    @institution = @primo_definition["institution"]

    @primo_default = ServiceStore.instantiate_service!(
      YAML.load(%{
        type: PrimoService
        service_id: NYUPrimo
        priority: 2 # After SFX, to get SFX metadata enhancement
        status: active
        base_url: http://bobcat.library.nyu.edu
        vid: NYU
        institution: NYU
        holding_search_institution: NYU
        holding_search_text: Search for this title in BobCat.
        suppress_holdings: [ !ruby/regexp '/LBWEB/', !ruby/regexp '/LNWEB/', !ruby/regexp '/LTWEB/', !ruby/regexp '/LWEB/', !ruby/regexp '/1Restricted Internet Resources/' ]
        ez_proxy: https://ezproxy.library.nyu.edu/login?url=
        service_types:
          - holding
          - holding_search
          - fulltext
          - table_of_contents
          - referent_enhance
          - cover_image
      }), nil)

    @primo_tns = ServiceStore.instantiate_service!(
      YAML.load(%{
        type: PrimoService
        priority: 2 # After SFX, to get SFX metadata enhancement
        status: active
        base_url: http://bobcat.library.nyu.edu
        vid: NS
        institution: NS
        holding_search_institution: NS
        holding_search_text: Search for this title in BobCat.
        suppress_holdings: [ !ruby/regexp '/LBWEB/', !ruby/regexp '/LNWEB/', !ruby/regexp '/LTWEB/', !ruby/regexp '/LWEB/', !ruby/regexp '/1Restricted Internet Resources/' ]
        ez_proxy: https://ezproxy.library.nyu.edu/login?url=
        primo_config: tns_primo.yml
        service_types:
          - primo_source
          - holding_search
          - fulltext
          - table_of_contents
          - referent_enhance
          - cover_image
        }), nil)

    @holding_search_institution = "NYU"
    @primo_minimum = PrimoService.new({
      "priority"=>1, "service_id" => "Primo",
      "base_url" => @base_url, "vid" => @vid, "institution" => @institution,
      "holding_search_institution" => @primo_definition["holding_search_institution"] })
    @primo_old_minimum = PrimoService.new({
      "priority"=>1, "service_id" => "Primo",
      "base_path" => @base_url, "base_view_id" => @vid, "institution" => @institution })
    @primo_minimum_no_config = PrimoService.new({
      "priority"=>1, "service_id" => "Primo",
      "base_url" => @base_url, "vid" => @vid, "institution" => @institution,
      "holding_search_institution" => @primo_definition["holding_search_institution"],
      "primo_config" => "missing_config.yml" })
  end

  # def test_primo_service_benchmarks
  #   request = requests(:primo_id_request)
  #   Benchmark.bmbm do |results|
  #     results.report("PrimoService Minimum Config:") {
  #       (1..10).each {
  #         @primo_minimum.handle(request)
  #       }
  #     }
  #     results.report("PrimoService Default Config:") {
  #       (1..10).each {
  #         @primo_default.handle(request)
  #       }
  #     }
  #   end
  # end
  #
  # def test_to_primo_source_benchmarks
  #   request = requests(:primo_id_request)
  #   @primo_default.handle(request)
  #   service_type = request.get_service_type('primo_source', {}).first
  #   Benchmark.bmbm do |results|
  #     results.report("PrimoService :to_primo_source via view data - NYUAleph:") {
  #       (1..10).each {
  #         service_type.view_data
  #       }
  #     }
  #     service_response = service_type.service_response
  #     results.report("PrimoService :to_primo_source - NYUAleph:") {
  #       (1..10).each {
  #         @primo_default.to_primo_source(service_response)
  #       }
  #     }
  #   end
  # end
  #
  # def test_primo_source_benchmarks
  #   request = requests(:primo_id_request)
  #   @primo_default.handle(request)
  #   primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
  #   Benchmark.bmbm do |results|
  #     results.report("PrimoSource - NYUAleph:") {
  #       (1..10).each {
  #         primo_source.handle(request)
  #       }
  #     }
  #   end
  # end
  #
  # def test_source_expand_benchmarks
  #   request = requests(:primo_id_request)
  #   @primo_default.handle(request)
  #   primo_source = request.get_service_type('primo_source', {}).first.view_data
  #   Benchmark.bmbm do |results|
  #     results.report("PrimoSource :expand - NYUAleph:") {
  #       (1..10).each {
  #         primo_source.expand
  #       }
  #     }
  #   end
  # end

  test "missing primo config" do
    @primo_minimum.send(:reset_primo_config)
    FileUtils.mv(PrimoService.default_config_file, "#{PrimoService.default_config_file}.bak")
    assert_nothing_raised {
      PrimoService.new({
        "priority"=>1, "service_id" => "Primo",
        "base_url" => @base_url, "vid" => @vid, "institution" => @institution,
        "holding_search_institution" => @primo_definition["holding_search_institution"]})
    }
    FileUtils.mv("#{PrimoService.default_config_file}.bak", PrimoService.default_config_file)
  end

  test_with_cassette("minimum config request by id", :primo) do
    request = requests(:primo_id_request)
    @primo_minimum.handle(request)
    request.referent.referent_values.reset
    request.dispatched_services.reset
    request.service_responses.reset
    test_data = {
      "aulast" => "Greene",
      "aufirst" => "Graham,",
      "au" => "Greene, Graham, 1904-1991",
      "title" => "Travels with my aunt",
      "btitle" => "Travels with my aunt",
      "place" => "New York",
      "pub" => "Penguin Books",
      "oclcnum" => "56781200",
      "lccn" => "2004559272"
    }
    test_data.each { |key, value|
      assert_equal(
        value,
        request.referent.metadata[key],
        "#{key} different than expected.")
    }
    holdings = request.get_service_type('holding')
    assert_equal(
      1, holdings.length)
    test_data = {
      :record_id => "nyu_aleph000062856",
      :source_id => "nyu_aleph",
      :original_source_id => "NYU01",
      :source_record_id => "000062856",
      :institution_code => "NYU",
      :institution => "NYU",
      :library_code => "BOBST",
      :library => "NYU Bobst",
      :status_code => "check_holdings",
      :status => "Check Availability",
      :collection => "Main Collection",
      :call_number => "(PR6013.R44 T7 2004 )",
      :origin => nil,
      :display_type => "book",
      :coverage => [],
      :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=nyu_aleph000062856&institution=NYU&vid=#{@vid}",
      :request_url => nil,
      :match_reliability => ServiceResponse::MatchExact,
      :request_link_supports_ajax_call => false }
    test_data.each { |key, value|
      assert_equal(
        value,
        holdings.first.view_data[key],
        "#{key} different than expected.")
    }
    tables_of_contents = request.get_service_type('table_of_contents')
    assert_equal(
      1, tables_of_contents.length)
    assert_equal(
      "https://ezproxy.library.nyu.edu/login?url=http://dummy.toc.com",
      tables_of_contents.first.url )
    assert_equal(
      "Dummy Table of Contents",
      tables_of_contents.first.display_text )
    test_data = {
      :record_id => "nyu_aleph000062856",
      :original_id => "nyu_aleph000062856",
      :display => "Dummy Table of Contents" }
    test_data.each { |key, value|
      assert_equal(
        value,
        tables_of_contents.first.service_data[key],
        "#{key} different than expected.")
    }
  end

  test_with_cassette("no config request by id", :primo) do
    request = requests(:primo_id_request)
    @primo_minimum_no_config.send(:reset_primo_config)
    @primo_minimum_no_config.handle(request)
    request.referent.referent_values.reset
    request.dispatched_services.reset
    request.service_responses.reset
    test_data = {
      "aulast" => "Greene",
      "aufirst" => "Graham,",
      "au" => "Greene, Graham, 1904-1991",
      "title" => "Travels with my aunt",
      "btitle" => "Travels with my aunt",
      "place" => "New York",
      "pub" => "Penguin Books",
      "oclcnum" => "56781200",
      "lccn" => "2004559272"
    }
    test_data.each { |key, value|
      assert_equal(
        value,
        request.referent.metadata[key],
        "#{key} different than expected.")
    }
    holdings = request.get_service_type('holding')
    assert_equal(
      1, holdings.length)
    test_data = {
      :record_id => "nyu_aleph000062856",
      :source_id => "nyu_aleph",
      :original_source_id => "NYU01",
      :source_record_id => "000062856",
      :institution_code => "NYU",
      :institution => "NYU",
      :library_code => "BOBST",
      :library => "BOBST",
      :status_code => "check_holdings",
      :status => "check_holdings",
      :collection => "Main Collection",
      :call_number => "(PR6013.R44 T7 2004 )",
      :origin => nil,
      :display_type => "book",
      :coverage => [],
      :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=nyu_aleph000062856&institution=NYU&vid=#{@vid}",
      :request_url => nil,
      :match_reliability => ServiceResponse::MatchExact,
      :request_link_supports_ajax_call => false }
    test_data.each { |key, value|
      assert_equal(
        value,
        holdings.first.view_data[key],
        "#{key} different than expected.")
    }
  end

  test_with_cassette("legacy config request by id", :primo) do
    request = requests(:primo_id_request)
    @primo_old_minimum.handle(request)
    request.referent.referent_values.reset
    request.dispatched_services.reset
    request.service_responses.reset
    test_data = {
      "aulast" => "Greene",
      "aufirst" => "Graham,",
      "au" => "Greene, Graham, 1904-1991",
      "title" => "Travels with my aunt",
      "btitle" => "Travels with my aunt",
      "place" => "New York",
      "pub" => "Penguin Books",
      "oclcnum" => "56781200",
      "lccn" => "2004559272"
    }
    test_data.each { |key, value|
      assert_equal(
        value,
        request.referent.metadata[key],
        "#{key} different than expected.")
    }
    holdings = request.get_service_type('holding')
    assert_equal(
      1, holdings.length)
    test_data = {
      :record_id => "nyu_aleph000062856",
      :source_id => "nyu_aleph",
      :original_source_id => "NYU01",
      :source_record_id => "000062856",
      :institution_code => "NYU",
      :institution => "NYU",
      :library_code => "BOBST",
      :library => "NYU Bobst",
      :status_code => "check_holdings",
      :status => "Check Availability",
      :collection => "Main Collection",
      :call_number => "(PR6013.R44 T7 2004 )",
      :origin => nil,
      :display_type => "book",
      :coverage => [],
      :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=nyu_aleph000062856&institution=NYU&vid=#{@vid}",
      :request_url => nil,
      :match_reliability => ServiceResponse::MatchExact,
      :request_link_supports_ajax_call => false }
    test_data.each { |key, value|
      assert_equal(
        value,
        holdings.first.view_data[key],
        "#{key} different than expected.")
    }
  end

  test_with_cassette("sfx owner but fulltext empty", :primo) do
    request = requests(:sfx_owner_but_fulltext_empty_request)
    @primo_default.handle(request)
    request.dispatched_services.reset
    request.service_responses.reset
    fulltexts = request.get_service_type('fulltext')
    url = @primo_default.send(:handle_ezproxy, fulltexts.first.url)
    assert(SfxUrl.sfx_controls_url?(url))
    assert_equal(1, fulltexts.length)
    assert_equal(
      "https://ezproxy.library.nyu.edu/login?url=http://proquest.umi.com/pqdweb?RQT=318&VName=PQD&clientid=9269&pmid=34445",
      fulltexts.first.url )
    assert_equal(
      "1997 - 2000 Full Text available from ProQuest",
      fulltexts.first.display_text )
    test_data = {
      :record_id => "nyu_aleph000935132",
      :original_id => "nyu_aleph000935132",
      :display => "1997 - 2000 Full Text available from ProQuest" }
    test_data.each { |key, value|
      assert_equal(
        value,
        fulltexts.first.service_data[key],
        "#{key} different than expected.")
    }
  end
end