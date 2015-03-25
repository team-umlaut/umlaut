require 'test_helper'
### 
### Tests adding the followig config values to the SFX service adaptor
###
### @boosted_targets - float specific targets to the top of full-text options
### @sunk_targets - sink specified targets to the bottom of full-text options

class SfxTargetPrecedenceTest < ActiveSupport::TestCase

  def test_boosted_target_appears_first
    sfx = Sfx.new({'priority' => 1, 
                   'base_url' => "http://example.org",
                   'boost_targets' => ['HIGHWIRE_PRESS_JOURNALS']
    })
    new_list = sfx.sort_boosted_responses(@@svc_list_example)
    assert_not_same @@svc_list_example, new_list
    assert_equal @@svc_list_example.length, new_list.length
      
    assert_equal new_list.first[:sfx_target_name], 'HIGHWIRE_PRESS_JOURNALS'
  end

  def test_boosted_wildcard
    sfx = Sfx.new({'priority' => 1, 
                   'base_url' => "http://example.org",
                   'boost_targets' => ['GALEGROUP_*']
    })
    new_list = sfx.sort_boosted_responses(@@svc_list_example)
    assert_not_same @@svc_list_example, new_list
      
    assert_equal new_list.first[:sfx_target_name], 'GALEGROUP_GREENR'
    assert_equal new_list.second[:sfx_target_name], 'GALEGROUP_BIOGRAPHY_IN_CONTEXT'
  end

  def test_sunk_target_appears_last
    sfx = Sfx.new({'priority' => 1, 
                   'base_url' => "http://example.org",
                   'sink_targets' => ['JSTOR_EARLY_JOURNAL_CONTENT_FREE']
    })
    
    new_list = sfx.sort_sunk_responses(@@svc_list_example)
    assert_not_same @@svc_list_example, new_list
    assert_equal @@svc_list_example.length, new_list.length

    assert_equal new_list.last[:sfx_target_name], 'JSTOR_EARLY_JOURNAL_CONTENT_FREE'
  end

  def test_sunk_wildcard
    sfx = Sfx.new({'priority' => 1, 
                   'base_url' => "http://example.org",
                   'sink_targets' => ['PROQUEST_*']
    })
    
    new_list = sfx.sort_sunk_responses(@@svc_list_example)
    assert_not_same @@svc_list_example, new_list
    assert_equal @@svc_list_example.length, new_list.length

    assert_equal new_list.last[:sfx_target_name], 'PROQUEST_MEDLINE_WITH_FULLTEXT'
  end

  def test_boosted_targets_appear_in_order
    sfx = Sfx.new({'priority' => 1, 
                   'base_url' => "http://example.org",
                   'boost_targets' => ['PROQUEST_CENTRAL_NEW_PLATFORM', 'HIGHWIRE_PRESS_JOURNALS']
    })
    new_list = sfx.sort_boosted_responses(@@svc_list_example)
    assert_not_same @@svc_list_example, new_list
    first_target = new_list[0]
    second_target = new_list[1]
    assert_equal first_target[:sfx_target_name], 'PROQUEST_CENTRAL_NEW_PLATFORM'
    assert_equal second_target[:sfx_target_name], 'HIGHWIRE_PRESS_JOURNALS'
  end

  def test_sunk_targets_appear_in_order
    sfx = Sfx.new({'priority' => 1, 
                   'base_url' => "http://example.org",
                   'sink_targets' => ['GALEGROUP_GREENR', 'EBSCOHOST_MAS_ULTRA_SCHOOL_EDITION']
    })
    new_list = sfx.sort_sunk_responses(@@svc_list_example)
    assert_not_same @@svc_list_example, new_list
    first_target = new_list[-2]
    second_target = new_list.last
    assert_equal first_target[:sfx_target_name], 'GALEGROUP_GREENR'
    assert_equal second_target[:sfx_target_name], 'EBSCOHOST_MAS_ULTRA_SCHOOL_EDITION'
  end

  @@svc_list_example = [

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
      :sfx_target_name => "GALEGROUP_BIOGRAPHY_IN_CONTEXT",
      :coverage_begin_date => Date.new(1983,1,1),
      :coverage_end_date => Date.new(2005,12,31)
    }
  ]

end