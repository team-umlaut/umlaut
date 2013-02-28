require 'test_helper'


class GoogleScholarLinkTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  # TODO: Fix up umlaut to make it easier to create request/referent
  # objects for testing!  
  def build_request(format, hash = {})
    context_object = OpenURL::ContextObject.new
    context_object.referent.set_format(format) if format
    
    hash.each_pair do |key, value|    
      context_object.referent.set_metadata(key.to_s, value.to_s)
    end
    
    rft = Referent.create_by_context_object(context_object)
    
    req = Request.new
    req.referent = rft
    req.save!
    
    return req
  end
  
  def setup
    @service = GoogleScholarLink.new({"priority" => 3, "service_id" => "GoogleScholarLink"})
  end
  
  def test_insufficient_metadata
    title_level = build_request("journal", :jtitle => "foo", :issn => "12345678")
    
    assert ! @service.should_link_out_to?(title_level)
        
    no_author = build_request("article", :issn => "12345678", :spage => "12", :volume => "2", :issue => "2", :atitle => "Some Article")
    
    assert ! @service.should_link_out_to?(no_author)        
  end
  
  def test_sufficient_metadata
    proceeding = build_request("journal", :atitle => "Human-Machine Collaborative Planning",
      :au => "Allen, James F.", :aufirst => "James", :auinitm => "F", :aulast => "Allen",
      :epage => "29", :genre => "proceeding", :spage => "27")    
    assert @service.should_link_out_to?(proceeding)
    
    article_little_metadata = build_request("journal", :genre => "article", :atitle => "Foo", :au => "Smith")    
    assert @service.should_link_out_to?(article_little_metadata)

    generic_with_article_level = build_request("journal", :atitle => "foo", 
      :au => "Smith", :issn => "12345678", :volume => "2", :issue => "2", :spage => "12")
    assert @service.should_link_out_to?(generic_with_article_level)    
  end
  
  def test_query
    aulast = build_request("journal", :atitle => "Human-Machine Collaborative Planning",
      :aulast => "Allen", :au => "Ignore this", :genre => "article")    
    assert_equal "allintitle: \"Human-Machine Collaborative Planning\" author:Allen", @service.construct_query(aulast)
    
    au_only = build_request("journal", :atitle => "Human-Machine Collaborative Planning",
      :au => "Allen, James P.", :genre => "article")
    assert_equal "allintitle: \"Human-Machine Collaborative Planning\" author:Allen author:James", @service.construct_query(au_only)        
  end
  
  test_with_cassette("live make a link", :google_scholar_link) do
    request = build_request("journal", :atitle => "Human-Machine Collaborative Planning",
      :aulast => "Allen", :au => "Ignore this", :genre => "article")
    
    @service.handle(request)
    
    assert_present request.service_responses    
  end
  
  test_with_cassette("live no link", :google_scholar_link) do
    request = build_request("journal", :jtitle => "foo", :issn => "12345678")

    @service.handle(request)
    
    assert_blank request.service_responses
  end
  
end
