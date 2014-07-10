# encoding: UTF-8
require 'test_helper'

require 'uri'
require 'rack/utils'

class ResolveControllerTest < ActionController::TestCase
  extend TestWithCassette
  fixtures :requests, :referents, :referent_values, :dispatched_services, :service_responses

  setup do
    @controller = ResolveController.new
  end

  test_with_cassette("nytimes by issn", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = requests(:nytimes)
    get :index, "umlaut.request_id" => umlaut_request.id
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
    umlaut_request = requests(:momo)
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
  end

  test_with_cassette("no holdings", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = requests(:advocate)
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
  end

  test_with_cassette("manually entered", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = requests(:manually_entered)
    get(:index, {'umlaut.request_id' => umlaut_request.id})
    assert_response :success
    assert_select('.resource_info_sections > div.alert.alert-error',
      {:text => "Warning: Find It does not know about a journal with this name. Please check your entry."}) do |error_divs|
      assert_equal 1, error_divs.size, "More than one error div"
      error_divs.each do |error_div|
        assert_select error_div, 'i.umlaut_icons-famfamfam-error', 1
      end
    end
  end
end
