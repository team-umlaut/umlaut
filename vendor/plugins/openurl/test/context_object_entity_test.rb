# encoding: UTF-8

class ContextObjectEntityTest < Test::Unit::TestCase

  def test_normalize_identifiers    

    # some ones that shouldn't be changed by normalization
    ["https://catalog.library.jhu.edu/bib/1",
     "http://dx.doi.org/foo",
     "info:isbn/foo",
     "urn:isbn:0395363411"].each do |id|
        assert_equal id, init_and_return_id(id)
     end

     # some ones that SHOULD be altered by normalization
     # some info ones
     
     
     assert_equal "info:doi/10.1126/science.275.5304.1320", init_and_return_id("doi:10.1126/science.275.5304.1320")
     
     assert_equal "info:pmid/9036860", init_and_return_id("pmid:9036860")
     
     assert_equal "info:sici/1046-8188(199501)13:1%3C69:FTTHBI%3E2.0.TX;2-4", init_and_return_id("sici:1046-8188(199501)13:1%3C69:FTTHBI%3E2.0.TX;2-4")
     
     assert_equal "info:oclcnum/53393962", init_and_return_id("oclcnum:53393962")

     assert_equal "info:lccn/12345", init_and_return_id("lccn:12345")      
     
     # some urn ones
     
     assert_equal "urn:isbn:0395363411", init_and_return_id("isbn:0395363411")
     
     assert_equal "urn:issn:1534-0481", init_and_return_id("issn:1534-0481")
  end

  def init_and_return_id(id)
    entity = OpenURL::ContextObjectEntity.new
    entity.add_identifier(id)
    return entity.identifiers.first
  end

end
