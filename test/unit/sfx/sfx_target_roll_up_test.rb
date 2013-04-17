require 'test_helper'

require 'nokogiri'


# Most of the SFX plugin isn't yet tested, but you have to start somewhere. 
#
# This specifically tests the target roll up feature, including
# the feature to turn SFX API coverage info into ruby Date objects
# in ServiceResponse[:coverage_begin_date] and [:coverage_end_date]

class SfxTargetRollUpTest < ActiveSupport::TestCase
  
  
  def test_basic_coverage_boundaries
      str = <<-EOS
      <target>
        <coverage>
          <coverage_text>
            <threshold_text>
            <coverage_statement>Available from 1909  until 1958</coverage_statement>
            </threshold_text>
            <embargo_text/>
          </coverage_text>
          <from>
            <year>1909</year>
          </from>
          <to>
            <year>1958</year>
          </to>
          <embargo/>
        </coverage>
      </target>
      EOS
      xml = Nokogiri::XML(str)
      
      sfx = Sfx.new({'priority' => 1, 'base_url' => "http://example.org"})
      
      (begin_date, end_date) = sfx.determine_coverage_boundaries(xml.at_xpath("./target"))
      
      assert_equal Date.new(1909, 1, 1), begin_date
      assert_equal Date.new(1958, 12, 31), end_date
      
    end
  
    def test_empty_to_coverage_boundaries
      str = <<-EOS
      <target>
        <coverage>
          <coverage_text>
            <threshold_text>
              <coverage_statement>Available from 1984</coverage_statement>
            </threshold_text>
            <embargo_text/>
          </coverage_text>
          <from>
            <year>1984</year>
          </from>
          <embargo/>
        </coverage>
      </target>
      EOS
      xml = Nokogiri::XML(str)
      
      sfx = Sfx.new({'priority' => 1, 'base_url' => "http://example.org"})
      
      (begin_date, end_date) = sfx.determine_coverage_boundaries(xml.at_xpath("./target"))
      
      assert_equal Date.new(1984, 1, 1), begin_date
      assert_nil end_date
      
    end
    
     def test_embargo_coverage_boundaries
      str = <<-EOS
      <target>
        <coverage>
          <coverage_text>
            <threshold_text>
              <coverage_statement>Available from 2001</coverage_statement>
            </threshold_text>
            <embargo_text>
              <embargo_statement>Most recent 3 month(s) not available</embargo_statement>
            </embargo_text>
          </coverage_text>
          <from>
            <year>2001</year>
          </from>
          <embargo>
            <availability>not_available</availability>
            <month>3</month>
            <days>90</days>
          </embargo>
        </coverage>
      </target>
      EOS
      xml = Nokogiri::XML(str)
      
      sfx = Sfx.new({'priority' => 1, 'base_url' => "http://example.org"})
      
      (begin_date, end_date) = sfx.determine_coverage_boundaries(xml.at_xpath("./target"))
      
      assert_equal Date.new(2001, 1, 1), begin_date
      assert_equal (Date.today - 90), end_date      
    end
    
    
    def test_conflicting_embargo_coverage_boundaries
      str = <<-EOS
      <target>
        <coverage>          
          <from>
            <year>2001</year>
          </from>
          <to>
            <year>#{Date.today.year}</year>
          </to>
          <embargo>
            <availability>not_available</availability>
            <year>2</year>
            <days>730</days>
          </embargo>
        </coverage>
      </target>
      EOS
      xml = Nokogiri::XML(str)
      
      sfx = Sfx.new({'priority' => 1, 'base_url' => "http://example.org"})
      
      (begin_date, end_date) = sfx.determine_coverage_boundaries(xml.at_xpath("./target"))
      
      assert_equal Date.new(2001, 1, 1), begin_date
      assert_equal (Date.today - 730), end_date      
    end
    
    def test_in_coverage
      str = <<-EOS
        <target>
          <coverage>
            <coverage_text>
              <threshold_text>
                <coverage_statement>Available in 2010</coverage_statement>
              </threshold_text>
              <embargo_text/>
            </coverage_text>
            <in>
              <year>2010</year>
            </in>
            <embargo/>
          </coverage>
        </target>
      EOS
      xml = Nokogiri::XML(str)
      
      sfx = Sfx.new({'priority' => 1, 'base_url' => "http://example.org"})
      
      (begin_date, end_date) = sfx.determine_coverage_boundaries(xml.at_xpath("./target"))
      
      assert_equal Date.new(2010, 1, 1), begin_date
      assert_equal Date.new(2010, 12, 31), end_date
      
    end
    
    def test_roll_up_responses_noop_with_no_config
      sfx = Sfx.new({'priority' => 1, 
                     'base_url' => "http://example.org"
      })
      
      new_list = sfx.roll_up_responses(@@svc_list_example_science, :coverage_sensitive => false)
        
      assert_equal new_list, @@svc_list_example_science
    end
    
    def test_roll_up_responses_non_coverage_sensitive
      sfx = Sfx.new({'priority' => 1, 
                     'base_url' => "http://example.org",
                     'roll_up_prefixes' => ["EBSCOHOST_", "JSTOR_", "PROQUEST_"]
      })

      new_list = sfx.roll_up_responses(@@svc_list_example_science, :coverage_sensitive => false)
        
      # Does not mutate in place
      assert_not_same @@svc_list_example_science, new_list
      
      # Rolls up two JSTOR's to first one    
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "JSTOR_"}.length
      assert new_list.find {|r| r[:sfx_target_name].start_with? "JSTOR_EARLY_JOURNAL_CONTENT_FREE"}
      
      # Rolls up four EBSCO to first      
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "EBSCOHOST_"}.length
      assert new_list.find {|r| r[:sfx_target_name].start_with? "EBSCOHOST_ACADEMIC_SEARCH_COMPLETE"}
      
      # Rolls up three PROQUEST to first
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "PROQUEST_"}.length
      assert new_list.find {|r| r[:sfx_target_name].start_with? "PROQUEST_CENTRAL_NEW_PLATFORM"}
      
      # Does NOT roll up GALEGROUP, not in config
      assert_equal 2, new_list.find_all {|r| r[:sfx_target_name].start_with? "GALEGROUP_"}.length
      
      # And one Highwire still in there too
      assert new_list.find {|r| r[:sfx_target_name].start_with? "HIGHWIRE_PRESS_JOURNALS"}
    end
    
    def test_roll_up_responses_non_coverage_sensitive
      sfx = Sfx.new({'priority' => 1, 
                     'base_url' => "http://example.org",
                     'roll_up_prefixes' => ["EBSCOHOST_", "JSTOR_", "PROQUEST_"]
      })

      new_list = sfx.roll_up_responses(@@svc_list_example_science, :coverage_sensitive => false)
        
      # Does not mutate in place
      assert_not_same @@svc_list_example_science, new_list
      
      # Rolls up two JSTOR's to first one    
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "JSTOR_"}.length
      assert new_list.find {|r| r[:sfx_target_name] == "JSTOR_EARLY_JOURNAL_CONTENT_FREE"}
      
      # Rolls up four EBSCO to first      
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "EBSCOHOST_"}.length
      assert new_list.find {|r| r[:sfx_target_name] == "EBSCOHOST_ACADEMIC_SEARCH_COMPLETE"}
      
      # Rolls up three PROQUEST to first
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "PROQUEST_"}.length
      assert new_list.find {|r| r[:sfx_target_name] == "PROQUEST_CENTRAL_NEW_PLATFORM"}
      
      # Does NOT roll up GALEGROUP, not in config
      assert_equal 2, new_list.find_all {|r| r[:sfx_target_name].start_with? "GALEGROUP_"}.length
      
      # And one Highwire still in there too
      assert new_list.find {|r| r[:sfx_target_name] == "HIGHWIRE_PRESS_JOURNALS"}
    end
    
    def test_roll_up_responses_yes_coverage_sensitive_starts_with
      sfx = Sfx.new({'priority' => 1, 
                     'base_url' => "http://example.org",
                     'roll_up_prefixes' => ["EBSCOHOST_", "JSTOR_", "PROQUEST_", "NODATES_", "UNBOUNDED_"]
      })

      new_list = sfx.roll_up_responses(@@svc_list_example_science, :coverage_sensitive => true)
        
      # Does not mutate in place
      assert_not_same @@svc_list_example_science, new_list
      
      # Rolls up two JSTOR's to SECOND one, with most coverage    
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "JSTOR_"}.length
      assert new_list.find {|r| r[:sfx_target_name] == "JSTOR_LIFE_SCIENCES_COLLECTION"}
      
      # Rolls up four EBSCO to first one, that's the coverage superset  
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "EBSCOHOST_"}.length
      assert new_list.find {|r| r[:sfx_target_name] == "EBSCOHOST_ACADEMIC_SEARCH_COMPLETE"}
      
      # Rolls up three PROQUEST to first AND second, unique coverages
      assert_equal 2, new_list.find_all {|r| r[:sfx_target_name].start_with? "PROQUEST_"}.length
      assert new_list.find {|r| r[:sfx_target_name].start_with? "PROQUEST_CENTRAL_NEW_PLATFORM"}
      assert new_list.find {|r| r[:sfx_target_name].start_with? "PROQUEST_ENGINEERING_JOURNALS_NEW_PLATFORM"}
      
      # Does NOT roll up GALEGROUP, not in config
      assert_equal 2, new_list.find_all {|r| r[:sfx_target_name].start_with? "GALEGROUP_"}.length
      
      # And one Highwire still in there too
      assert new_list.find {|r| r[:sfx_target_name].start_with? "HIGHWIRE_PRESS_JOURNALS"}
      
      # Roll up three with no dates specified to first one
      assert_equal 1, new_list.find_all {|r| r[:sfx_target_name].start_with? "NODATES_"}.length
      assert new_list.find {|r| r[:sfx_target_name].start_with? "NODATES_ONE"}
      
      # Nil endpoints considered unbouded
      assert_equal 2, new_list.find_all {|r| r[:sfx_target_name].start_with? "UNBOUNDED_"}.length
      assert new_list.find {|r| r[:sfx_target_name].start_with? "UNBOUNDED_ONE"}
      assert new_list.find {|r| r[:sfx_target_name].start_with? "UNBOUNDED_THREE"}
    end
  
    
    # A long list example of ServiceResponses to test roll_up func.
    # This was created by taking the one from our actual SFX result
    # for journal Science, but then modding to exhibit various kinds
    # of coverage overlap to test them all. 
    @@svc_list_example_science = [
        { :display_text => "JSTOR Early Journal Content",
          :sfx_target_name => "JSTOR_EARLY_JOURNAL_CONTENT_FREE",
          :coverage_begin_date => Date.new(1880,1,1),
          :coverage_end_date => Date.new(1922,12,31)
        },
        { :display_text => "JSTOR_LIFE_SCIENCES_COLLECTION",
          :sfx_target_name => "JSTOR_LIFE_SCIENCES_COLLECTION",
          :coverage_begin_date => Date.new(1880,1,1),
          :coverage_end_date => Date.new(2007,12,31)
        },
        { :display_text => "EBSCOHOST_ACADEMIC_SEARCH_COMPLETE",
          :sfx_target_name => "EBSCOHOST_ACADEMIC_SEARCH_COMPLETE",
          :coverage_begin_date => Date.new(1997,1,1),
          :coverage_end_date => Date.new(2010,12,31)
        },
        { :display_text => "EBSCOHOST_HEALTH_SOURCE_NURSING_ACADEMIC",
          :sfx_target_name => "EBSCOHOST_HEALTH_SOURCE_NURSING_ACADEMIC",
          :coverage_begin_date => Date.new(1997,1,1),
          :coverage_end_date => Date.new(2004,12,31)
        },
        { :display_text => "EBSCOHOST_MAS_ULTRA_SCHOOL_EDITION",
          :sfx_target_name => "EBSCOHOST_MAS_ULTRA_SCHOOL_EDITION",
          :coverage_begin_date => Date.new(1997,1,1),
          :coverage_end_date => Date.new(2006,12,31)
        },
        { :display_text => "EBSCOHOST_MASTERFILE_PREMIER",
          :sfx_target_name => "EBSCOHOST_MASTERFILE_PREMIER",
          :coverage_begin_date => Date.new(1997,1,1),
          :coverage_end_date => Date.new(2004,12,31)
        },
        { :display_text => "HIGHWIRE_PRESS_JOURNALS",
          :sfx_target_name => "HIGHWIRE_PRESS_JOURNALS",
          :coverage_begin_date => Date.new(1997,1,1),
          :coverage_end_date => Date.new(2006,12,31)
        },
        { :display_text => "PROQUEST_CENTRAL_NEW_PLATFORM",
          :sfx_target_name => "PROQUEST_CENTRAL_NEW_PLATFORM",
          :coverage_begin_date => Date.new(1988,1,1),
          :coverage_end_date => Date.new(2005,12,31)
        },
        { :display_text => "PROQUEST_ENGINEERING_JOURNALS_NEW_PLATFORM",
          :sfx_target_name => "PROQUEST_ENGINEERING_JOURNALS_NEW_PLATFORM",
          :coverage_begin_date => Date.new(1980,1,1),
          :coverage_end_date => Date.new(2000,12,31)
        },
        { :display_text => "PROQUEST_MEDLINE_WITH_FULLTEXT",
          :sfx_target_name => "PROQUEST_MEDLINE_WITH_FULLTEXT",
          :coverage_begin_date => Date.new(1988,1,1),
          :coverage_end_date => Date.new(2005,12,31)
        },
        { :display_text => "GALEGROUP_GREENR",
          :sfx_target_name => "GALEGROUP_GREENR",
          :coverage_begin_date => Date.new(1983,1,1),
          :coverage_end_date => Date.new(2005,12,31)
        },
        { :display_text => "GALEGROUP_BIOGRAPHY_IN_CONTEXT",
          :sfx_target_name => "GALEGROUP_GREENR",
          :coverage_begin_date => Date.new(1983,1,1),
          :coverage_end_date => Date.new(2005,12,31)
        },
        { :display_text => "no dates no prefix does not raise",
          :sfx_target_name => "UNRELATED_WHATEVER"
        },
        { :display_text => "prefix, two no dates 1",
          :sfx_target_name => "NODATES_ONE"
        },
        { :display_text => "prefix, two no dates 2",
          :sfx_target_name => "NODATES_TWO"
        },
        { :display_text => "prefix, two no dates 3",
          :sfx_target_name => "NODATES_THREE"
        },
        { :display_text => "UNBOUNDED_ONE",
          :sfx_target_name => "UNBOUNDED_ONE",
          :coverage_begin_date => nil,
          :coverage_end_date => Date.new(2005,12,31)
        },
        { :display_text => "UNBOUNDED_TWO",
          :sfx_target_name => "UNBOUNDED_TWO",
          :coverage_begin_date => Date.new(1983,1,1),
          :coverage_end_date => Date.new(2005,12,31)
        },
        { :display_text => "UNBOUNDED_THREE",
          :sfx_target_name => "UNBOUNDED_THREE",
          :coverage_begin_date => Date.new(2000,1,1),
          :coverage_end_date => nil
        }
      ]
  
end
