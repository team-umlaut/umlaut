require File.dirname(__FILE__) + '/../test_helper'

class InstitutionListTest < Test::Unit::TestCase

    def setup      
      # Tell to use our basic services.yml, not the live one.
      InstitutionList.yaml_path =  RAILS_ROOT+"/lib/generators/umlaut_local/templates/institutions.yml-dist"      
      
    end

    def test_default_institutions
      default_list = InstitutionList.instance.default_institutions

      # Our test institutions.yml has one default institutions
      assert_not_nil(default_list)
      assert_equal(1, default_list.length)
      default_list.each do |i|
        assert_kind_of(Institution, i)
      end      
      
    end

    # subsequent calls to 'get' should return the same singleton
    # copy of a given institution. 
    def test_same_institution
      i1 = InstitutionList.instance.get("global")
      i2 = InstitutionList.instance.get("global")

      assert_equal(i1, i2)
    end
    
end
