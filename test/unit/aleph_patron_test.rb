require File.dirname(__FILE__) + '/../test_helper'
class AlephPatronTest < ActiveSupport::TestCase
  def setup
    ServiceList.yaml_path =  RAILS_ROOT+"/lib/generators/umlaut_local/templates/services.yml-dist"
    @primo_config = YAML.load_file("#{RAILS_ROOT}/config/umlaut_config/primo.yml")
    @nyu_aleph_config = @primo_config["sources"]["nyu_aleph"]
    @rest_url = @nyu_aleph_config["rest_url"]
    @aleph_doc_library = "NYU01"
    @aleph_doc_number = "000062856"
    @nyuidn = "N12162279"
    @aleph_adm_library = "NYU50"
    @aleph_item_id = "NYU50000062856000010"
    @aleph_renew_item_id = "NYU50000647049"
    @pickup_location = "BOBST"
    @bogus_url = "http://library.nyu.edu/bogus"
  end

  # Test exception handling for bogus response.
  def test_bogus_response
    patron = Exlibris::Aleph::Patron.new(@nyuidn, @bogus_url)
    assert_raise(REXML::ParseException) { patron.loans }
    assert_raise(REXML::ParseException) { patron.renew_loans() }
    assert_raise(REXML::ParseException) { patron.renew_loans(@aleph_renew_item_id) }
    assert_raise(RuntimeError) { patron.place_hold(@aleph_adm_library, @aleph_doc_library, @aleph_doc_number, @aleph_item_id, {:pickup_location => @pickup_location}) }
  end

  # Test search for a single Primo document.
  def test_patron
    patron = Exlibris::Aleph::Patron.new(@nyuidn, @rest_url)
    loans = patron.loans
    assert_nil(patron.error, "Failure in #{patron.class} while getting loans: #{patron.error}")
    #renew_loans = patron.renew_loans()
    #assert_nil(patron.error, "Failure in #{patron.class} while renewing all loans: #{patron.error}")
    #renew_loans = patron.renew_loans(@aleph_renew_item_id)
    #assert_nil(patron.error, "Failure in #{patron.class} while renewing loan #{@aleph_renew_item_id}: #{patron.error}")
    assert_raise(RuntimeError) { patron.place_hold(@aleph_adm_library, @aleph_doc_library, @aleph_doc_number, @aleph_item_id, {}) }
    place_hold = patron.place_hold(@aleph_adm_library, @aleph_doc_library, @aleph_doc_number, @aleph_item_id, {:pickup_location => @pickup_location})
    assert_nil(patron.error, "Failure in #{patron.class} while placing hold: #{patron.error}")
  end
end