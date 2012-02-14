require 'test_helper'
class PrimoServiceTest < ActiveSupport::TestCase
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
        ez_proxy: !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
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
        suppress_holdings: [ !ruby/regexp '/\$\$LBWEB/', !ruby/regexp '/\$\$LNWEB/', !ruby/regexp '/\$\$LTWEB/', !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
        ez_proxy: !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
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
        suppress_holdings: [ !ruby/regexp '/\$\$LBWEB/', !ruby/regexp '/\$\$LNWEB/', !ruby/regexp '/\$\$LTWEB/', !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
        ez_proxy: !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
        primo_config: tns_primo.yml
        service_types:
          - primo_source
          - holding_search
          - fulltext
          - table_of_contents
          - referent_enhance
          - cover_image
        }), nil)
    
    
    
    @holding_search_institution = 
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
  
  def test_primo_service_benchmarks
    request = requests(:primo_id_request)
    Benchmark.bmbm do |results|
      results.report("PrimoService Minimum Config:") {
        (1..10).each {
          @primo_minimum.handle(request)
        }
      }
      results.report("PrimoService Default Config:") {
        (1..10).each {
          @primo_default.handle(request)
        }
      }
    end
  end
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
  
  def test_primo_service_minimum
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
      :id_one => "Main Collection", 
      :id_two => "(PR6013.R44 T7 2004 )", 
      :collection => "Main Collection", 
      :call_number => "(PR6013.R44 T7 2004 )", 
      :origin => nil, 
      :display_type => "book", 
      :coverage => [], 
      :notes => "",
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
  
  def test_primo_service_minimum_no_config
    request = requests(:primo_id_request)
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
      :id_one => "Main Collection", 
      :id_two => "(PR6013.R44 T7 2004 )", 
      :collection => "Main Collection", 
      :call_number => "(PR6013.R44 T7 2004 )", 
      :origin => nil, 
      :display_type => "book", 
      :coverage => [], 
      :notes => "",
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
  
  def test_primo_service_legacy_settings_minimum
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
      :id_one => "Main Collection", 
      :id_two => "(PR6013.R44 T7 2004 )", 
      :collection => "Main Collection", 
      :call_number => "(PR6013.R44 T7 2004 )", 
      :origin => nil, 
      :display_type => "book", 
      :coverage => [], 
      :notes => "",
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
  
#   def test_available_nyu_aleph
#     # Available
#     request = requests(:primo_id_request)
#     @primo_default.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       1, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       1, holdings.length)
#     test_data = { 
#       :record_id => "nyu_aleph000062856", 
#       :source_id => "nyu_aleph", 
#       :original_source_id => "NYU01", 
#       :source_record_id => "000062856",
#       :institution_code => "NYU", 
#       :institution => "NYU", 
#       :library_code => "BOBST",
#       :library => "NYU Bobst",
#       :status_code => "available", 
#       :status => "Available", 
#       :id_one => "Main Collection", 
#       :id_two => "(PR6013.R44 T7 2004)", 
#       :collection => "Main Collection", 
#       :call_number => "(PR6013.R44 T7 2004)", 
#       :origin => nil, 
#       :display_type => "book", 
#       :coverage => [], 
#       :notes => "",
#       :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000062856&sub_library=BOBST", 
#       :request_url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000062856&sub_library=BOBST",
#       :match_reliability => ServiceResponse::MatchExact, 
#       :request_link_supports_ajax_call => true }
#     test_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[key],
#         "#{key} different than expected.")
#     }
#     source_data = {
#       :aleph_doc_library => "NYU01",
#       :aleph_sub_library => "NYU Bobst",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_collection => "Main Collection",
#       :aleph_call_number => "(PR6013.R44 T7 2004)",
#       :aleph_doc_number => "000062856",
#       :aleph_url => "http://alephstage.library.nyu.edu",
#       :illiad_url => "http://illiaddev.library.nyu.edu",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_item_id => "NYU50000062856000010",
#       :aleph_item_adm_library => "NYU50",
#       :aleph_item_sub_library_code => "BOBST",
#       :aleph_item_collection_code => "MAIN",
#       :aleph_item_doc_number => "000062856",
#       :aleph_item_sequence_number => "1.0",
#       :aleph_item_barcode => "31142041146104",
#       :aleph_item_status_code => "01",
#       :aleph_item_process_status_code => nil,
#       :aleph_item_circulation_status => "On Shelf",
#       :aleph_item_location => "PR6013.R44&nbsp;T7 2004",
#       :aleph_item_description => nil,
#       :aleph_item_hol_doc_number => "002992203"
#     }
#     source_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[:source_data][key],
#         "#{key} different than expected.")
#     }
#   end
# 
#   def test_available_tns_aleph
#     # Available
#     request = requests(:primo_id_request)
#     @primo_tns.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       1, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       1, holdings.length)
#     test_data = { 
#       :record_id => "nyu_aleph000062856", 
#       :source_id => "nyu_aleph", 
#       :original_source_id => "NYU01", 
#       :source_record_id => "000062856",
#       :institution_code => "NYU", 
#       :institution => "NYU", 
#       :library_code => "BOBST",
#       :library => "NYU Bobst",
#       :status_code => "available", 
#       :status => "Available", 
#       :id_one => "Main Collection", 
#       :id_two => "(PR6013.R44 T7 2004)", 
#       :collection => "Main Collection", 
#       :call_number => "(PR6013.R44 T7 2004)", 
#       :origin => nil, 
#       :display_type => "book", 
#       :coverage => [], 
#       :notes => "",
#       :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000062856&sub_library=BOBST", 
#       :request_url => nil, 
#       :match_reliability => ServiceResponse::MatchExact, 
#       :request_link_supports_ajax_call => true }
#     test_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[key],
#         "#{key} different than expected.")
#     }
#     source_data = {
#       :aleph_doc_library => "NYU01",
#       :aleph_sub_library => "NYU Bobst",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_collection => "Main Collection",
#       :aleph_call_number => "(PR6013.R44 T7 2004)",
#       :aleph_doc_number => "000062856",
#       :aleph_url => "http://alephstage.library.nyu.edu",
#       :illiad_url => "http://illiaddev.library.nyu.edu",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_item_id => "NYU50000062856000010",
#       :aleph_item_adm_library => "NYU50",
#       :aleph_item_sub_library_code => "BOBST",
#       :aleph_item_collection_code => "MAIN",
#       :aleph_item_doc_number => "000062856",
#       :aleph_item_sequence_number => "1.0",
#       :aleph_item_barcode => "31142041146104",
#       :aleph_item_status_code => "01",
#       :aleph_item_process_status_code => nil,
#       :aleph_item_circulation_status => "On Shelf",
#       :aleph_item_location => "PR6013.R44&nbsp;T7 2004",
#       :aleph_item_description => nil,
#       :aleph_item_hol_doc_number => "002992203"
#     }
#     source_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[:source_data][key],
#         "#{key} different than expected.")
#     }
# end
# 
# def test_checked_out_nyu_aleph
#     request = requests(:primo_checked_out_request)
#     @primo_default.handle(request)
#     request.referent.referent_values.reset
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       1, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       1, holdings.length)
#     test_data = { 
#       :record_id => "nyu_aleph000742457", 
#       :source_id => "nyu_aleph", 
#       :original_source_id => "NYU01", 
#       :source_record_id => "000742457",
#       :institution_code => "NYU", 
#       :institution => "NYU", 
#       :library_code => "BOBST",
#       :library => "NYU Bobst",
#       :status_code => "checked_out", 
#       :status => "Due: 08/25/11", 
#       :id_one => "Main Collection", 
#       :id_two => "(DR557 .J86 2001)", 
#       :collection => "Main Collection", 
#       :call_number => "(DR557 .J86 2001)", 
#       :origin => nil, 
#       :display_type => "book", 
#       :coverage => [], 
#       :notes => "",
#       :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000742457&sub_library=BOBST", 
#       :request_url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000742457&sub_library=BOBST", 
#       :match_reliability => ServiceResponse::MatchExact, 
#       :request_link_supports_ajax_call => true }
#     test_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[key],
#         "#{key} different than expected.")
#     }
#     source_data = {
#       :aleph_doc_library => "NYU01",
#       :aleph_sub_library => "NYU Bobst",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_collection => "Main Collection",
#       :aleph_call_number => "(DR557 .J86 2001)",
#       :aleph_doc_number => "000742457",
#       :aleph_url => "http://alephstage.library.nyu.edu",
#       :illiad_url => "http://illiaddev.library.nyu.edu",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_item_id => "NYU50000742457000010",
#       :aleph_item_adm_library => "NYU50",
#       :aleph_item_sub_library_code => "BOBST",
#       :aleph_item_collection_code => "MAIN",
#       :aleph_item_doc_number => "000742457",
#       :aleph_item_sequence_number => "1.0",
#       :aleph_item_barcode => "31142031951646",
#       :aleph_item_status_code => "01",
#       :aleph_item_process_status_code => nil,
#       :aleph_item_circulation_status => "08/25/11",
#       :aleph_item_location => "DR557&nbsp;.J86 2001",
#       :aleph_item_description => nil,
#       :aleph_item_hol_doc_number => "002815266"
#     }
#     source_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[:source_data][key],
#         "#{key} different than expected.")
#     }
# end
# 
# def test_in_process_nyu_aleph
#     request = requests(:primo_bobst_in_processing_request)
#     @primo_default.handle(request)
#     request.referent.referent_values.reset
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       1, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       1, holdings.length)
#     test_data = { 
#       :record_id => "nyu_aleph002723601", 
#       :source_id => "nyu_aleph", 
#       :original_source_id => "NYU01", 
#       :source_record_id => "002723601",
#       :institution_code => "NYU", 
#       :institution => "NYU", 
#       :library_code => "BOBST",
#       :library => "NYU Bobst",
#       :status_code => "overridden_by_nyu_aleph", 
#       :status => "In Processing", 
#       :id_one => "Main Collection", 
#       :id_two => "(PN691 .B78 1983)", 
#       :collection => "Main Collection", 
#       :call_number => "(PN691 .B78 1983)", 
#       :origin => nil, 
#       :display_type => "book", 
#       :coverage => [], 
#       :notes => "",
#       :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=002723601&sub_library=BOBST", 
#       :request_url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=002723601&sub_library=BOBST", 
#       :match_reliability => ServiceResponse::MatchExact, 
#       :request_link_supports_ajax_call => true }
#     test_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[key],
#         "#{key} different than expected.")
#     }
#     source_data = {
#       :aleph_doc_library => "NYU01",
#       :aleph_sub_library => "NYU Bobst",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_collection => "Main Collection",
#       :aleph_call_number => "(PN691 .B78 1983)",
#       :aleph_doc_number => "002723601",
#       :aleph_url => "http://alephstage.library.nyu.edu",
#       :illiad_url => "http://illiaddev.library.nyu.edu",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_item_id => "NYU50002723601000010",
#       :aleph_item_adm_library => "NYU50",
#       :aleph_item_sub_library_code => "BOBST",
#       :aleph_item_collection_code => "MAIN",
#       :aleph_item_doc_number => "002723601",
#       :aleph_item_sequence_number => "1.0",
#       :aleph_item_barcode => "31142011075952",
#       :aleph_item_status_code => "01",
#       :aleph_item_process_status_code => "BD",
#       :aleph_item_circulation_status => "At Bindery",
#       :aleph_item_location => "PN691&nbsp;.B78 1983",
#       :aleph_item_description => nil,
#       :aleph_item_hol_doc_number => "000631538"
#     }
#     source_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[:source_data][key],
#         "#{key} different than expected.")
#     }
# end
# 
# def test_journal1_nyu_aleph
#     request = requests(:primo_journal1_request)
#     @primo_default.handle(request)
#     request.referent.referent_values.reset
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       4, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       4, holdings.length)
#     test_data = { 
#       :record_id => "nyu_aleph002895625", 
#       :source_id => "nyu_aleph", 
#       :original_source_id => "NYU01", 
#       :source_record_id => "002895625",
#       :institution_code => "NYU", 
#       :institution => "NYU", 
#       :library_code => "BOBST",
#       :library => "NYU Bobst",
#       :status_code => "check_holdings", 
#       :status => "Check Availability", 
#       :id_one => "Main Collection", 
#       :id_two => "(ML1 .M819 )", 
#       :collection => "Main Collection", 
#       :call_number => "(ML1 .M819 )", 
#       :origin => nil, 
#       :display_type => "journal", 
#       :coverage => ["Available in Main Collection: VOLUMES: 1-89 (YEARS: 1915-2006)"], 
#       :notes => "",
#       :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=002895625&sub_library=BOBST", 
#       :request_url => nil, 
#       :match_reliability => ServiceResponse::MatchExact, 
#       :request_link_supports_ajax_call => false }
#     test_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[key],
#         "#{key} different than expected.")
#     }
#     source_data = {
#       :aleph_doc_library => "NYU01",
#       :aleph_sub_library => "NYU Bobst",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_collection => "Main Collection",
#       :aleph_call_number => "(ML1 .M819 )",
#       :aleph_doc_number => "002895625",
#       :aleph_sub_library_code => "BOBST"
#     }
#     source_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[:source_data][key],
#         "#{key} different than expected.")
#     }
# end
# 
# def test_journal1_tns_aleph
#     request = requests(:primo_journal1_request)
#     @primo_tns.handle(request)
#     request.referent.referent_values.reset
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       4, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       4, holdings.length)
#     test_data = { 
#       :record_id => "nyu_aleph002895625", 
#       :source_id => "nyu_aleph", 
#       :original_source_id => "NYU01", 
#       :source_record_id => "002895625",
#       :institution_code => "NYU", 
#       :institution => "NYU", 
#       :library_code => "BOBST",
#       :library => "NYU Bobst",
#       :status_code => "check_holdings", 
#       :status => "Check Availability", 
#       :id_one => "Main Collection", 
#       :id_two => "(ML1 .M819 )", 
#       :collection => "Main Collection", 
#       :call_number => "(ML1 .M819 )", 
#       :origin => nil, 
#       :display_type => "journal", 
#       :coverage => ["Available in Main Collection: VOLUMES: 1-89 (YEARS: 1915-2006)"], 
#       :notes => "",
#       :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=002895625&sub_library=BOBST", 
#       :request_url => nil, 
#       :match_reliability => ServiceResponse::MatchExact, 
#       :request_link_supports_ajax_call => false }
#     test_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[key],
#         "#{key} different than expected.")
#     }
#     source_data = {
#       :aleph_doc_library => "NYU01",
#       :aleph_sub_library => "NYU Bobst",
#       :aleph_sub_library_code => "BOBST",
#       :aleph_collection => "Main Collection",
#       :aleph_call_number => "(ML1 .M819 )",
#       :aleph_doc_number => "002895625",
#       :aleph_sub_library_code => "BOBST"
#     }
#     source_data.each { |key, value|
#       assert_equal(
#         value, 
#         holdings.first.view_data[:source_data][key],
#         "#{key} different than expected.")
#     }
# end
# 
# def test_journal2_nyu_aleph
#     # Journal 2
#     request = requests(:primo_journal2_request)
#     @primo_default.handle(request)
#     request.referent.referent_values.reset
#     request.dispatched_services.reset
#     request.service_types.reset
#     # record_id = request.referent.metadata["primo"]
#     assert_equal("Macomb", request.referent.metadata["place"]);
#     assert_equal("Center for Business and Economic Research, Western Illinois University]", request.referent.metadata["pub"]);
#     primo_sources = request.get_service_type('primo_source')
#     assert(1 <= primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert(1 <= holdings.length)
#     assert_equal(primo_sources.length, holdings.length)
#     assert_equal("NYU", holdings.first.view_data[:institution])
#     assert_equal("NYU Bobst", holdings.first.view_data[:library])
#     assert_equal("Main Collection", holdings.first.view_data[:id_one])
#     assert_equal("http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=002736245&sub_library=BOBST", holdings.first.view_data[:url])
#     assert_equal("(HB1 .J55 )", holdings.first.view_data[:id_two])
#     assert_equal("Check Availability", holdings.first.view_data[:status])
#   end
# 
#   def test_journal3_nyu_aleph
#       # Journal 3
#       request = requests(:primo_journal3_request)
#       @primo_default.handle(request)
#       request.referent.referent_values.reset
#       request.dispatched_services.reset
#       request.service_types.reset
#       # record_id = request.referent.metadata["primo"]
#       assert_equal("Sydney", request.referent.metadata["place"]);
#       assert_equal("Association for the Journal of Religious History]", request.referent.metadata["pub"]);
#       primo_sources = request.get_service_type('primo_source')
#       assert_equal(0, primo_sources.length)
#       primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#       primo_source.handle(request)
#       request.dispatched_services.reset
#       request.service_types.reset
#       holdings = request.get_service_type('holding')
#       assert_equal(0, holdings.length)
#       assert_equal(primo_sources.length, holdings.length)
#   end
# 
#   def test_journal4_nyu_aleph
#       # Journal 4
#       request = requests(:primo_journal4_request)
#       @primo_default.handle(request)
#       request.referent.referent_values.reset
#       request.dispatched_services.reset
#       request.service_types.reset
#       # record_id = request.referent.metadata["primo"]
#       assert_equal("Waltham, MA", request.referent.metadata["place"]);
#       assert_equal("Published for the Board by the Massachusetts Medical Society", request.referent.metadata["pub"]);
#       primo_sources = request.get_service_type('primo_source')
#       assert_equal(0, primo_sources.length)
#       primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#       primo_source.handle(request)
#       request.dispatched_services.reset
#       request.service_types.reset
#       holdings = request.get_service_type('holding')
#       assert_equal(0, holdings.length)
#       assert_equal(primo_sources.length, holdings.length)
#   end
#   
#   def test_journal5_nyu_aleph
#       request = requests(:primo_journal5_request)
#       @primo_default.handle(request)
#       request.referent.referent_values.reset
#       request.dispatched_services.reset
#       request.service_types.reset
#       # record_id = request.referent.metadata["primo"]
#       primo_sources = request.get_service_type('primo_source')
#       assert_equal(1, primo_sources.length)
#       primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#       primo_source.handle(request)
#       request.dispatched_services.reset
#       request.service_types.reset
#       holdings = request.get_service_type('holding')
#       assert_equal(1, holdings.length)
#       assert_equal(primo_sources.length, holdings.length)
#   end
#   
#   def test_bobst_genre_discrepancy
#       request = requests(:primo_bobst_problem1_request)
#       @primo_default.handle(request)
#       request.dispatched_services.reset
#       request.service_types.reset
#       primo_sources = request.get_service_type('primo_source')
#       assert_equal(
#         1, primo_sources.length)
#       primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#       primo_source.handle(request)
#       request.dispatched_services.reset
#       request.service_types.reset
#       holdings = request.get_service_type('holding')
#       assert_equal(
#         1, holdings.length)
#       test_data = { 
#         :record_id => "nyu_aleph000509288", 
#         :source_id => "nyu_aleph", 
#         :original_source_id => "NYU01", 
#         :source_record_id => "000509288",
#         :institution_code => "NYU", 
#         :institution => "NYU", 
#         :library_code => "BOBST",
#         :library => "NYU Bobst",
#         :status_code => "available", 
#         :status => "Available", 
#         :id_one => "Main Collection", 
#         :id_two => "(ML410.J33 M47 2005a)", 
#         :collection => "Main Collection", 
#         :call_number => "(ML410.J33 M47 2005a)", 
#         :origin => nil, 
#         :display_type => "book", 
#         :coverage => [], 
#         :notes => "",
#         :url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000509288&sub_library=BOBST", 
#         :request_url => "http://alephstage.library.nyu.edu/F?func=item-global&doc_library=NYU01&local_base=PRIMOCOMMON&doc_number=000509288&sub_library=BOBST",
#         :match_reliability => ServiceResponse::MatchExact, 
#         :request_link_supports_ajax_call => true }
#       test_data.each { |key, value|
#         assert_equal(
#           value, 
#           holdings.first.view_data[key],
#           "#{key} different than expected.")
#       }
#       source_data = {
#         :aleph_doc_library => "NYU01",
#         :aleph_sub_library => "NYU Bobst",
#         :aleph_sub_library_code => "BOBST",
#         :aleph_collection => "Main Collection",
#         :aleph_call_number => "(ML410.J33 M47 2005a)",
#         :aleph_doc_number => "000509288",
#         :aleph_url => "http://alephstage.library.nyu.edu",
#         :illiad_url => "http://illiaddev.library.nyu.edu",
#         :aleph_sub_library_code => "BOBST",
#         :aleph_item_id => "NYU50000509288000010",
#         :aleph_item_adm_library => "NYU50",
#         :aleph_item_sub_library_code => "BOBST",
#         :aleph_item_collection_code => "MAIN",
#         :aleph_item_doc_number => "000509288",
#         :aleph_item_sequence_number => "1.0",
#         :aleph_item_barcode => "31142045676163",
#         :aleph_item_status_code => "01",
#         :aleph_item_process_status_code => nil,
#         :aleph_item_circulation_status => "On Shelf",
#         :aleph_item_location => "ML410.J33&nbsp;M47 2005a",
#         :aleph_item_description => nil,
#         :aleph_item_hol_doc_number => "003227224"
#       }
#       source_data.each { |key, value|
#         assert_equal(
#           value, 
#           holdings.first.view_data[:source_data][key],
#           "#{key} different than expected.")
#       }
#   end
#   
#   def test_critical_inquiry_bug
#     request = requests(:critical_inquiry_request)
#     @primo_default.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     primo_sources = request.get_service_type('primo_source')
#     assert_equal(
#       4, primo_sources.length)
#     primo_source = ServiceList.instance.instantiate!("NYU_Primo_Source", nil)
#     primo_source.handle(request)
#     request.dispatched_services.reset
#     request.service_types.reset
#     holdings = request.get_service_type('holding')
#     assert_equal(
#       4, holdings.length)
#   end
#   
#   def test_sfx_owner_but_fulltext_empty
#       request = requests(:sfx_owner_but_fulltext_empty_request)
#       @primo_default.handle(request)
#       request.dispatched_services.reset
#       request.service_types.reset
#       fulltext = request.get_service_type('fulltext')
#       assert_equal(0, fulltext.length)
#   end
end