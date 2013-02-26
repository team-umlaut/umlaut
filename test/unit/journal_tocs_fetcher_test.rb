require 'test_helper'
class JournalTocsFetcherTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  # what registered email to use for testing? In the JournalTOCs docs,
  # they use this email, which works, so we're going to use it for testing, sorry. 
  @@registered_email = ENV["journal_tocs_registered_email"] || "macleod.roddy@gmail.com"
  
  
  test_with_cassette("fetch_xml with hits", :journal_tocs) do
    fetcher = JournalTocsFetcher.new("1533290X", :registered_email => @@registered_email)
    
    xml = fetcher.fetch_xml
    
    assert_not_nil xml
    assert_kind_of Nokogiri::XML::Document, xml
  end
  
  test_with_cassette("error on bad base url", :journal_tocs) do
    fetcher = JournalTocsFetcher.new("1533290X", :base_url => "http://doesnotexist.jhu.edu/", :registered_email => @@registered_email)
    
    assert_raise JournalTocsFetcher::FetchError do
      xml = fetcher.fetch_xml
    end        
  end
  
  test_with_cassette("error on error response", :journal_tocs) do
    fetcher = JournalTocsFetcher.new("1533290X", :base_url => "http://www.journaltocs.ac.uk/bad_url", :registered_email => @@registered_email)
    
    assert_raise JournalTocsFetcher::FetchError do
      xml = fetcher.fetch_xml
    end        
  end
  
  test_with_cassette("error on bad registered email", :journal_tocs) do
    fetcher = JournalTocsFetcher.new("1533290X",  :registered_email => "unregistered@nowhere.com")
    
    assert_raise JournalTocsFetcher::FetchError do
      xml = fetcher.fetch_xml
    end
  end
  
  test_with_cassette("smoke test", :journal_tocs) do
    fetcher = JournalTocsFetcher.new("1533290X",  :registered_email => @@registered_email)
    
    items = fetcher.items
    
    assert_present items
    assert_kind_of Array, items
    items.each do |item|
      assert_kind_of BentoSearch::ResultItem, item
    end
  end
  
  test_with_cassette("fills out metadata", :journal_tocs) do
    # this ISSN has reasonably complete data in RSS feed
    items = JournalTocsFetcher.new("1600-5740",  :registered_email => @@registered_email).items
    
    assert_present items.first
    
    first = items.first
    
    assert_present first.title
    assert_present first.authors
    assert_present first.authors.first.display
    assert_present first.abstract
    assert_present first.link
    assert_present first.doi
    assert_present first.publisher
    assert_present first.source_title
    assert_present first.volume
    assert_present first.issue
    assert_present first.start_page
    assert_present first.end_page
    assert_present first.publication_date
    
  end
  
  
end
