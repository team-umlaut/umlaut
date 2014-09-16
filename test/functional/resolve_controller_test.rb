# encoding: UTF-8
require 'test_helper'

require 'uri'
require 'rack/utils'

# This test is a mess, and tests a weird setup involving fixtures such that the request
# tested already has some (but not neccesarily all) services completed and service response
# objects created.  Testing the resolve controller is hard, with it's threading and it's
# standard use of services that make HTTP calls. I tried to change this into something
# reasonable (perhaps using only MockServices), but failed in the time I had available for now.
#
# Note on testing the resolve controller: Making a request to ResolveController#index will
# fire off a background thread (which fires off more bg threads) to dispatch background services. 
#
# If you don't wait on these, they will be going on in the background of possible subsequent
# tests, which is messy. And more painfully, they'll wind up making http requests OUTSIDE
# of the VCR block, since the VCR block ends with the threads still going on their own. 
#
# So it's important to wait on them before ending the VCR block or otherwise going on. 
# Immediately after doing an HTTP interaction, you can get the bg thread by:
#
#     bg_thread = @controller.bg_thread
#
# (Do this before making another HTTP interaction which will reset @controller). 
# Then you can wait on it by `bg_thread.join`. 
class ResolveControllerTest < ActionController::TestCase
  extend TestWithCassette

  setup do
    @controller = ResolveController.new
  end

  test_with_cassette("nytimes by issn", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = nytimes_request!

    get :index, "umlaut.request_id" => umlaut_request.id

    # Wait on all bg services
    @controller.bg_thread.join
    
    assert_response :success
    assert_select "title", "Find It | The New York times"
    assert_select "h1", "Find It"
    # Resource title assertion
    assert_select "h2.title", "The New York times"
    # Background updater assertions
    assert_select ".umlaut-resolve-container > script" do |scripts|
      assert_equal 1, scripts.size
      # Make sure we have an HtmlUpdater in our script
      scripts.each do |script|
        assert_match /var updater = new Umlaut.HtmlUpdater\("http:\/\/test\.host\/", "umlaut\.request_id=#{umlaut_request.id}", "en"\);/, script.to_s
      end
    end
    # Citation section assertions
    assert_select ".umlaut-main .umlaut-resource-info dl.citation-info" do |dls|
      assert_equal 1, dls.size
      dls.each do |dl|
        assert_select dl, "dt", 1
        assert_select dl, "dt" do |dts|
          assert dts.last, "ISSN:"
        end
        assert_select dl, "dd", 1
        assert_select dl, "dd" do |dds|
          assert dds.last, "0362-4331"
        end
      end
    end
    # Fulltext section assertions
    assert_select ".umlaut-main .umlaut-section.fulltext" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
        assert_select section, ".response_list" do |response_lists|
          assert_select section, ".section_heading h3", { :count => 1, :text => "Online Access" }
          assert_select section, "li.response_item", 4
        end
      end
    end
    # Holding section assertions
    assert_select ".umlaut-main .umlaut-section.holding" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".umlaut-holdings", 1
        assert_select section, ".umlaut-holdings .umlaut-holding" do |holdings|
          # This record only has 1 holding
          assert_equal 1, holdings.size
          holdings.each do |holding|
            # Make sure the edition warning shows up.
            assert_select holding, ".umlaut-holding-match-reliability", 1
            # Make sure the coverage shows up.
            assert_select holding, ".umlaut-holding-coverage", 1
            assert_select holding, ".umlaut-holding-coverage li", 2
            # Make sure the notes show up.
            assert_select holding, ".umlaut-holding-notes", 1
          end
        end
      end
    end
    # Export citation section assertions
    assert_select ".umlaut-sidebar .umlaut-section.export_citation" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".section_heading h3", { :count => 1, :text => ServiceTypeValue.find("export_citation").display_name_pluralize.titlecase }
        assert_select section, ".response_list", 1
      end
    end
    # Highlighted link section assertions
    assert_select ".umlaut-sidebar .umlaut-section.highlighted_link" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".section_heading h3", { :count => 1, :text => "See also" }
        assert_select section, ".response_list", 1
      end
    end
    # Help section assertions
    assert_select ".umlaut-sidebar .umlaut-section.help" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".section_heading h3", { :count => 1, :text => "Question? Problem? Contact:" }
        assert_select section, ".response_list", 1
      end
    end
    # Modal assertions
    assert_select ".modal" do |modals|
      assert_equal 1, modals.size
      modals.each do |modal|
        assert_select modal, ".modal-header", { :count => 1 }
        assert_select modal, ".modal-body", { :count => 1 }
        assert_select modal, ".modal-footer", { :count => 1 }
      end
    end
  end

  test_with_cassette("POSTed OpenURL redirects to GET", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    # an actual post request Gale GREENr was sending us
    pparams = {"genre"=>"article", "sid"=>"gale:GRNR", "__char_set"=>"utf8", "spage"=>"138", "issn"=>"0016-7398", "issue"=>"2", "pid"=>"info:sid/gale:ugnid:balt85423", "date"=>"2010", "aulast"=>"Hedley, Peter J.", "au"=>"Hedley, Peter J.", "atitle"=>"Evolution of the Irrawaddy delta region since 1850.(Report)", "title"=>"The Geographical Journal", "aufirst"=>"Hedley, Peter J.", "volume"=>"176"}
    post(:index, pparams)

    assert_response :redirect

    redirect_uri = URI.parse(@response.redirect_url)

    assert_equal "/resolve", redirect_uri.path

    # Redirected params is a subset of pparams, pparams can have extra
    # stuff maybe, we don't care.
    redirected_params = Rack::Utils.parse_nested_query redirect_uri.query
    assert  (redirected_params.to_a - pparams.to_a).empty?, "Redirected params include all of original POSTed params"
  end

  test_with_cassette("fulltext with edition warning", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = fake_umlaut_request("?aufirst=Michael&aulast=Ende&btitle=Momo&genre=book&isbn=038519093X&pub=Doubleday")
    umlaut_request.service_responses.build(
      service_id: "InternetArchive",
      display_text: "the Internet Archive: Open Source Book",
      url: "http://archive.org/details/MomoOvveroLarcanaStoria...",
      service_data: {:match_reliability=>"unsure", :edition_str=>"Momo, ovvero l'arcana storia dei ladri di tempo e della bambina che restituÃ¬ agli uomini il tempo trafugato"},
      service_type_value_name: "fulltext"
    )
    umlaut_request.save!

    get(:index, {'umlaut.request_id' => umlaut_request.id})

    assert_response :success
    assert_select 'div#fulltext ul.response_list li.response_item' do |elements|
      assert_equal(1, elements.size)
      elements.each do |element|
        assert_select element, "a", {:count => 1, :href => "", :text => "the Internet Archive: Open Source Book"}
        assert_select element, 'div.edition_warning', {:count => 1,
          :text => "Edition information Momo, ovvero l&#39;arcana storia dei ladri di tempo e della bambina che restituÃ¬ agli uomini il tempo trafugato"}
      end
    end

    # Wait on all bg services
    @controller.bg_thread.join
  end

  test_with_cassette("no holdings", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = fake_umlaut_request("/?issn=1832-9373&jtitle=Advocate&rfr_id=info%3Asid%2Fsfxit.com%3Acitation&object_id=2670000000017711")
    umlaut_request.service_responses.build(
      service_id: "SFX", 
      display_text: "Gale Cengage Newsstand", 
      url: "http://find.galegroup.com/openurl/openurl?res_id=i...", 
      service_type_value_name: "fulltext",
      service_data: {:authentication=>"", :source=>"SFX/", :coverage=>"Available from 2009.", :sfx_base_url=>"http://sfx.library.nyu.edu/sfxlcl41", :sfx_obj_index=>1, :sfx_target_index=>1, :sfx_request_id=>"3766609", :sfx_target_service_id=>"1000000000003344", :sfx_target_name=>"GALEGROUP_IT_NEWSSTAND", :citation_volume=>nil, :citation_issue=>nil, :citation_spage=>nil, :debug_info=>" Target: GALEGROUP_IT_NEWSSTAND ; SFX object ID: 2670000000017711"}
    )
    umlaut_request.save!

    get(:index, {'umlaut.request_id' => umlaut_request.id})
    assert_response :success
    assert_select 'div#fulltext ul.response_list li.response_item' do |elements|
      assert_equal(1, elements.size)
      elements.each do |element|
        assert_select element, "a", {:count => 1, :href => "", :text => "Gale Cengage Newsstand"}
        assert_select element, 'div.response_coverage_statement', {:count => 1, :text => "Available from 2009."}
      end
    end
    # Assert no holdings
    assert_select 'div#holding div.umlaut-holdings', :count => 0

    # Wait on all bg services
    @controller.bg_thread.join
  end

  test_with_cassette("manually entered", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = fake_umlaut_request("?genre=article&jtitle=Entry+Manual&rfr_id=info%3Asid%2Fsfxit.com%3Acitation")

    get(:index, {'umlaut.request_id' => umlaut_request.id})
    assert_response :success
    assert_select('.resource_info_sections > div.alert.alert-danger',
      {:text => "Warning: Find It does not know about a journal with this name. Please check your entry."}) do |error_divs|
      assert_equal 1, error_divs.size, "More than one error div"
      error_divs.each do |error_div|
        assert_select error_div, 'i.umlaut_icons-famfamfam-error', 1
      end
    end

    # Wait on all bg services
    @controller.bg_thread.join
  end

  def nytimes_request!
    umlaut_request = fake_umlaut_request("?title=The+New+York+times&issn=0362-4331")

    umlaut_request.service_responses.build(
      service_id: "SFX", 
      display_text: "EBSCOhost Newspaper Source Plus", 
      url: "http://search.ebscohost.com/login.aspx?direct=true&db=n5h&scope=site&jn=New+York+Times", 
      service_data: {:coverage=>"Available from 1985.", }, 
      service_type_value_name: "fulltext"
    )
    umlaut_request.service_responses.build(
      service_id: "DummyService", 
      display_text: "Library holding", 
      url: "http://holding.library.edu/DOCID", 
      notes: "Some notes.", 
      service_data: {:title=>"The New York times", :status=>"Check Availability", :display_type=>"journal", :request_url=>"http://request.library.edu/DOCID", :call_number=>"(Call Number)", :collection=>"Library Holding", :collection_str=>"Library Holding", :coverage_str_array=>["Coverage 1", "Coverage 2"], :match_reliability=>"unsure"}, 
      service_type_value_name: "holding"
    )
    umlaut_request.service_responses.build(
      service_id: "SFX", 
      display_text: "EBSCOhost Business Abstracts with Full Text", 
      url: "http://search.ebscohost.com/direct.asp?db=bft&jn=3...",
      service_data: {:authentication=>"", :source=>"SFX/", :coverage=>"Available from 2011.", :sfx_base_url=>"http://sfx.library.edu/local", :sfx_obj_index=>1, :sfx_target_index=>1, :sfx_request_id=>"2576884", :sfx_target_service_id=>"3450000000000057", :sfx_target_name=>"EBSCOHOST_BUSINESS_ABSTRACTS_FULL_TEXT_WILSON", :citation_volume=>nil, :citation_issue=>nil, :citation_spage=>nil, :debug_info=>" Target: EBSCOHOST_BUSINESS_ABSTRACTS_FULL_TEXT_WILSON ; SFX object ID: 110975413976006"}, 
      service_type_value_name: "fulltext"
    )
    umlaut_request.service_responses.build(
      service_id: "EmailExport", 
      display_text: "Email", 
      service_data: {:link_supports_ajax_call=>true},
      service_type_value_name: "export_citation"
    )
    umlaut_request.service_responses.build(
      service_id: "SFX", 
      display_text: "Ask a Librarian", 
      url: "http://library.edu/ask", 
      service_data: {:display_text=>"Ask a Librarian", :url=>"http://library.edu/ask"}, 
      service_type_value_name: "help"
    )
    umlaut_request.service_responses.build(
      service_id: "SFX",
      display_text: "EBSCOhost Business Abstracts with Full Text",
      url: "https://ezproxy.library.edu/login?url=http://searc...",
      service_data: {:authentication=>"", :source=>"SFX/", :coverage=>"Available from 2011.", :sfx_base_url=>"http://sfx.library.edu/local", :sfx_obj_index=>1, :sfx_target_index=>1, :sfx_request_id=>"2567643", :sfx_target_service_id=>"3450000000000057", :sfx_target_name=>"EBSCOHOST_BUSINESS_ABSTRACTS_FULL_TEXT_WILSON", :citation_volume=>nil, :citation_issue=>nil, :citation_spage=>nil, :debug_info=>" Target: EBSCOHOST_BUSINESS_ABSTRACTS_FULL_TEXT_WILSON ; SFX object ID: 110975413976006"}, 
      service_type_value_name: "fulltext"
    )
    umlaut_request.service_responses.build(
      service_id: "Ulrichs", 
      display_text: "Periodical information", 
      url: "https://ulrichsweb.serialssolutions.com/api/openur...", 
      service_type_value_name: "highlighted_link"
    )
    umlaut_request.service_responses.build(
      service_id: "Ulrichs",
      display_text: "Periodical information",
      url: "https://ulrichsweb.serialssolutions.com/api/openur...", 
      service_type_value_name: "highlighted_link"
    )
    umlaut_request.service_responses.build(
      service_id: "SFX", 
      display_text: "Proquest",
      url: "http://proquest.umi.com/pqdweb?RQT=318&VName=PQD&c...",
      service_data: {:display_text=>"Proquest", :url=>"http://proquest.umi.com/pqdweb?RQT=318&VName=PQD&clientid=9269&pmid=7818"},
      service_type_value_name: "fulltext"
    )
    umlaut_request.save!

    return umlaut_request
  end
end
