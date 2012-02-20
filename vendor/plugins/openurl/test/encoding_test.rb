# encoding: UTF-8


require 'yaml'

unless "".respond_to?(:encoding)
  puts <<eos
  
=================================================================
  WARNING: Can't run encoding tests unless under ruby 1.9 
      #{__FILE__} 
  Encoding tests will NOT be run.
=================================================================

eos
else

  class EncodingTest < Test::Unit::TestCase
    
      
    def test_kev
      # Load from string explicitly set to binary, to make sure it ends up utf-8
      # anyhow. 
      raw_kev = "url_ver=Z39.88-2004&url_tim=2003-04-11T10%3A09%3A15TZD&url_ctx_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Actx&ctx_ver=Z39.88-2004&ctx_enc=info%3Aofi%2Fenc%3AUTF-8&ctx_id=10_8&ctx_tim=2003-04-11T10%3A08%3A30TZD&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&rft.genre=book&rft.aulast=Vergnaud&rft.auinit=J.-R&rft.btitle=D%C3%A9pendances+et+niveaux+de+repr%C3%A9sentation+en+syntaxe&rft.date=1985&rft.pub=Benjamins&rft.place=Amsterdam%2C+Philadelphia&rfe_id=urn%3Aisbn%3A0262531283&rfe_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&rfe.genre=book&rfe.aulast=Chomsky&rfe.auinit=N&rfe.btitle=Minimalist+Program&rfe.isbn=0262531283&rfe.date=1995&rfe.pub=The+MIT+Press&rfe.place=Cambridge%2C+Mass&svc_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Asch_svc&svc.abstract=yes&rfr_id=info%3Asid%2Febookco.com%3Abookreader".force_encoding("ascii-8bit")
      
      assert_equal("ASCII-8BIT", raw_kev.encoding.name)
      
      ctx = OpenURL::ContextObject.new_from_kev(raw_kev)
      
      assert_equal("UTF-8", ctx.referent.metadata['btitle'].encoding.name) 
      assert_equal("Dépendances et niveaux de représentation en syntaxe", ctx.referent.metadata["btitle"])
  
      # serialized as utf-8
      assert_equal("UTF-8", ctx.kev.encoding.name)        
    end
    
    def test_xml
      assert_equal("ASCII-8BIT", @@xml_with_utf8.encoding.name)
      
      ctx = OpenURL::ContextObject.new_from_xml(@@xml_with_utf8)
      
      assert_equal("UTF-8", ctx.referent.metadata['btitle'].encoding.name) 
      assert_equal("Dépendances et niveaux de représentation en syntaxe", ctx.referent.metadata["btitle"])
  
      # serialized as utf-8
      assert_equal("UTF-8", ctx.xml.encoding.name)
    end
    
    
    
    @@xml_with_utf8 = <<eos
<ctx:context-objects xmlns:ctx='info:ofi/fmt:xml:xsd:ctx' xsi:schemaLocation='info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'><ctx:context-object identifier='10_8' timestamp='2003-04-11T10:08:30TZD' version='Z39.88-2004'><ctx:referent><ctx:metadata-by-val><ctx:format>info:ofi/fmt:xml:xsd:book</ctx:format><ctx:metadata><rft:book xmlns:rft='info:ofi/fmt:xml:xsd:book' xsi:schemaLocation='info:ofi/fmt:xml:xsd:book http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:book'><rft:genre>book</rft:genre><rft:btitle>Dépendances et niveaux de représentation en syntaxe</rft:btitle><rft:date>1985</rft:date><rft:pub>Benjamins</rft:pub><rft:place>Amsterdam, Philadelphia</rft:place><rft:authors><rft:author><rft:aulast>Vergnaud</rft:aulast><rft:auinit>J.-R</rft:auinit></rft:author></rft:authors></rft:book></ctx:metadata></ctx:metadata-by-val></ctx:referent><ctx:referring-entity><ctx:metadata-by-val><ctx:format>info:ofi/fmt:xml:xsd:book</ctx:format><ctx:metadata><rfe:book xmlns:rfe='info:ofi/fmt:xml:xsd:book' xsi:schemaLocation='info:ofi/fmt:xml:xsd:book http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:book'><rfe:genre>book</rfe:genre><rfe:btitle>Minimalist Program</rfe:btitle><rfe:isbn>0262531283</rfe:isbn><rfe:date>1995</rfe:date><rfe:pub>The MIT Press</rfe:pub><rfe:place>Cambridge, Mass</rfe:place><rfe:authors><rfe:author><rfe:aulast>Chomsky</rfe:aulast><rfe:auinit>N</rfe:auinit></rfe:author></rfe:authors></rfe:book></ctx:metadata></ctx:metadata-by-val><ctx:identifier>urn:isbn:0262531283</ctx:identifier></ctx:referring-entity><ctx:referrer><ctx:identifier>info:sid/ebookco.com:bookreader</ctx:identifier></ctx:referrer><ctx:service-type><ctx:metadata-by-val><ctx:format>info:ofi/fmt:xml:xsd:sch_svc</ctx:format><ctx:metadata><svc:abstract xmlns:svc='info:ofi/fmt:xml:xsd:sch_svc'>yes</svc:abstract></ctx:metadata></ctx:metadata-by-val></ctx:service-type></ctx:context-object></ctx:context-objects>
eos
  # Make sure it's got a raw encoding, so we can test it winds up utf-8 anyhow
  @@xml_with_utf8.force_encoding("ascii-8bit")
      
  end
end
