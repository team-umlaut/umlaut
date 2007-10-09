require 'test_helper'

class ActiveRecordSetProviderTest < Test::Unit::TestCase

  def test_list_sets
    doc = REXML::Document.new(@provider.list_sets)
    sets = doc.elements["/OAI-PMH/ListSets"]
    assert sets.size == 4
    assert sets[0].elements["//setName"].text == "Set A"
  end
  
  def test_set_a
    doc = REXML::Document.new(@provider.list_records(:set => "A"))
    assert_equal 20, doc.elements['OAI-PMH/ListRecords'].to_a.size
  end
  
  def test_set_b
    doc = REXML::Document.new(@provider.list_records(:set => "B"))
    assert_equal 10, doc.elements['OAI-PMH/ListRecords'].to_a.size
  end
  
  def test_set_ab
    doc = REXML::Document.new(@provider.list_records(:set => "A:B"))
    assert_equal 10, doc.elements['OAI-PMH/ListRecords'].to_a.size
  end
  
  def test_record_with_multiple_sets
    assert_equal 2, DCField.find(32).sets.size
  end

  def setup
    @provider = ARSetProvider.new
    ARLoader.load
    define_sets
  end

  def teardown
    ARLoader.unload
    DCSet.connection.execute("delete from dc_fields_dc_sets")
    DCSet.delete_all
  end

  def define_sets
    set_a = DCSet.create(:name => "Set A", :spec => "A")
    set_b = DCSet.create(:name => "Set B", :spec => "B")
    set_c = DCSet.create(:name => "Set B", :spec => "B")
    set_ab = DCSet.create(:name => "Set A:B", :spec => "A:B")
  
    DCField.find([1,2,3,4,5,6,7,8,9,10]).each do |record|
      set_a.dc_fields << record
    end
    
    DCField.find([11,12,13,14,15,16,17,18,19,20]).each do |record|
      set_b.dc_fields << record
    end

    DCField.find([21,22,23,24,25,26,27,28,29,30]).each do |record|
      set_ab.dc_fields << record
    end
  
    DCField.find([31,32,33,34,35,36,37,38,39,40]).each do |record|
      set_a.dc_fields << record
      set_c.dc_fields << record
    end
  end
end