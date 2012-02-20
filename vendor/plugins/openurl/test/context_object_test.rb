# encoding: UTF-8

Encoding.default_external = "UTF-8" if defined? Encoding

class ContextObjectTest < Test::Unit::TestCase

  def test_create_ctx    
    require 'cgi'
    ctx = OpenURL::ContextObject.new
    ctx.referent.set_format('journal')
    assert_equal(ctx.referent.format, 'journal')
    # Set some referent metadata
    ctx.referent.set_metadata('jtitle', 'Ariadne')
    assert_equal(ctx.referent.metadata['jtitle'], 'Ariadne')
    # Overwrite the title
    ctx.referent.set_metadata('jtitle', 'Nature')
    assert_equal(ctx.referent.metadata['jtitle'], 'Nature')
    # Set some identifiers
    ctx.referent.add_identifier('doi:10.1038/nature06100')
    assert_equal(ctx.referent.identifier, "info:doi/10.1038/nature06100")
    assert_equal(ctx.referent.identifiers, ["info:doi/10.1038/nature06100"])
    ctx.referent.add_identifier('info:pmid/17728715')
    assert_equal(ctx.referent.identifiers, ["info:doi/10.1038/nature06100", 'info:pmid/17728715'])
    assert_equal(ctx.referent.identifier, "info:doi/10.1038/nature06100")    
    ctx.referrer.add_identifier('info:sid/google')
    assert_equal(ctx.referrer.identifier, "info:sid/google")
  end
  
  def test_load_kev
    require 'yaml'
    data = YAML.load_file('test/test.yml')    
    ctx = OpenURL::ContextObject.new_from_kev(data["context_objects"]["kev"])
    self.test_kev_values(ctx)
    ctx = OpenURL::ContextObject.new_from_kev(data["context_objects"]["kev_hybrid"])
    self.test_kev_hybrid_values(ctx)    
    ctx = OpenURL::ContextObject.new_from_kev(data["context_objects"]["kev_0_1"])
    self.test_kev_01_values(ctx)
  end

  def test_old_sid_translation
    params = {"sid" => "elsevier", "isbn" => "dummy"}
    ctx = OpenURL::ContextObject.new_from_form_vars(params)

    assert_equal "info:sid/elsevier", ctx.referrer.identifiers.first, "translate 0.1 style sid into sort-of-legal 1.0 style rfr_id with info:sid URI"    
  end
  
  def test_load_xml
    require 'yaml'
    data = YAML.load_file('test/test.yml')
    xml = File.new(data["context_objects"]["xml_doc"]).read
    ctx = OpenURL::ContextObject.new_from_xml(xml)  
    self.test_xml_values(ctx)
  end
  
  def test_load_form_vals
    require 'yaml'
    require 'cgi'
    data = YAML.load_file('test/test.yml')
    cgi = CGI.parse(data["context_objects"]["kev"])
    ctx = OpenURL::ContextObject.new_from_form_vars(cgi)
    self.test_kev_values(ctx)
  end

  def test_load_metalib_form_params
    require 'yaml'
    require 'cgi'
    data = YAML.load_file('test/test.yml')
    params = data["context_objects"]["metalib_sap2_form_vars"]

    ctx = OpenURL::ContextObject.new_from_form_vars(params)
    rft_metadata = ctx.referent.metadata
    
    assert_equal("Cooper Jr", rft_metadata["aulast"])
    assert_equal("William E", rft_metadata["aufirst"])
    assert_equal("Escape responses of cryptic frogs (Anura: Brachycephalidae: Craugastor) to simulated terrestrial and aerial predators.", rft_metadata["atitle"])
    assert_equal("Behaviour", rft_metadata["stitle"])
    assert_equal("2008", rft_metadata["date"])
    assert_equal("145", rft_metadata["volume"])

    # And test the even WORSELY damaged metalib form vars
    params = data["context_objects"]["metalib_sap2_form_vars_worse"]
    ctx = OpenURL::ContextObject.new_from_form_vars(params)
    rft_metadata = ctx.referent.metadata

    assert_equal("N Engl J Med", rft_metadata["title"])
    assert_equal("2008", rft_metadata["date"])
  end

  def test_load_cgi_style_metalib_form_params
    require 'yaml'
    require 'cgi'

    data = YAML.load_file('test/test.yml')
    params = data["context_objects"]["cgi_style_metalib_form_params"]

    ctx = OpenURL::ContextObject.new_from_form_vars(params)
    rft_metadata = ctx.referent.metadata

    assert_equal("Abushahba", rft_metadata["aulast"])
    assert_equal("Effect of grafting materials on osseointegration of dental implants surrounded by circumferential bone defects. An experimental study in the dog.", rft_metadata["atitle"])
  end
  
  def test_oai_dc
    require 'yaml'
    data = YAML.load_file('test/test.yml')
    xml = File.new(data["context_objects"]["oai_dc_ctx"]).read
    ctx = OpenURL::ContextObject.new_from_xml(xml)  
    self.test_oai_dc_values(ctx)    
    ctx2 = OpenURL::ContextObject.new_from_xml(ctx.xml)
    self.test_oai_dc_values(ctx2)    
  end
  
  def test_marc
    require 'yaml'
    data = YAML.load_file('test/test.yml')
    xml = File.new(data["context_objects"]["marc_21_ctx"]).read
    ctx = OpenURL::ContextObject.new_from_xml(xml)  
    self.test_marc_values(ctx)    
    ctx2 = OpenURL::ContextObject.new_from_xml(ctx.xml)
    self.test_marc_values(ctx2)
  end

  # Had problems importing a record with an 'au' metadata author.
  # Fixed it, so adding a test for it. 
  def test_au
    require 'yaml'
    data = YAML.load_file('test/test.yml')
    xml = File.new(data['context_objects']['scholarly_au_ctx']).read
    ctx = OpenURL::ContextObject.new_from_xml(xml)

    assert_equal( ctx.referent.metadata["title"], "The adventures of Tom Sawyer")
    assert_equal( ctx.referent.metadata["au"], "Twain, Mark")
  end
  
  def test_xml_output
    require 'yaml'
    require 'rexml/document'
    data = YAML.load_file('test/test.yml')
    ctx = OpenURL::ContextObject.new_from_kev(data["context_objects"]["kev"])
    doc = REXML::Document.new(ctx.xml)
    root = doc.root
    assert_equal(root.name, "context-objects")
    assert_equal(root.prefix, "ctx")
    assert_equal(root.namespace('ctx'), "info:ofi/fmt:xml:xsd:ctx")
    assert_equal(root.namespace('xsi'), "http://www.w3.org/2001/XMLSchema-instance")
    xml_schema = root.attribute('schemaLocation')
    assert_equal(xml_schema.value, "info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx")
    assert_equal(xml_schema.prefix, "xsi")
    assert_equal(xml_schema.namespace, root.namespace(xml_schema.prefix))
    ctx_obj = root.elements["ctx:context-object"]
    assert(ctx_obj.is_a?(REXML::Element))
    assert_equal(ctx_obj.attributes['timestamp'], '2003-04-11T10:08:30TZD')
    assert_equal(ctx_obj.attributes['version'], 'Z39.88-2004')
    assert_equal(ctx_obj.attributes['identifier'], '10_8')
    rft = ctx_obj.elements["ctx:referent"]
    assert(rft.is_a?(REXML::Element))
    mbv = rft.elements['ctx:metadata-by-val']
    assert(mbv.is_a?(REXML::Element))
    fmt = mbv.elements['ctx:format']
    assert(fmt.is_a?(REXML::Element))
    assert_equal(fmt.get_text.value, "info:ofi/fmt:xml:xsd:book")
    metadata = mbv.elements['ctx:metadata']
    assert(metadata.is_a?(REXML::Element))
    book = metadata.elements['rft:book']
    assert(book.is_a?(REXML::Element))
    assert_equal(book.namespace('rft'), "info:ofi/fmt:xml:xsd:book")
    assert_equal(book.attribute('schemaLocation').value, "info:ofi/fmt:xml:xsd:book http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:book")
    authors_cont = book.elements['rft:authors']
    assert(authors_cont.is_a?(REXML::Element))
    author_cont = authors_cont.elements['rft:author']
    assert(author_cont.is_a?(REXML::Element))    
    assert_equal(author_cont.elements['rft:aulast'].get_text.value, "Vergnaud")
    assert_equal(author_cont.elements['rft:auinit'].get_text.value, "J.-R")
    btitle = book.elements['rft:btitle']
    assert(btitle.is_a?(REXML::Element))    
    assert_equal(btitle.get_text.value, "Dépendances et niveaux de représentation en syntaxe")
    genre = book.elements['rft:genre']
    assert(genre.is_a?(REXML::Element))
    assert_equal(genre.get_text.value, "book")
    date = book.elements['rft:date']
    assert(date.is_a?(REXML::Element))
    assert_equal(date.get_text.value, "1985")    
    pub = book.elements['rft:pub']
    assert(pub.is_a?(REXML::Element))
    assert_equal(pub.get_text.value, "Benjamins")    
    place = book.elements['rft:place']
    assert(place.is_a?(REXML::Element))
    assert_equal(place.get_text.value, "Amsterdam, Philadelphia")  

    rfe = ctx_obj.elements["ctx:referring-entity"]
    assert(rfe.is_a?(REXML::Element))
    mbv = rfe.elements['ctx:metadata-by-val']
    assert(mbv.is_a?(REXML::Element))
    fmt = mbv.elements['ctx:format']
    assert(fmt.is_a?(REXML::Element))
    assert_equal(fmt.get_text.value, "info:ofi/fmt:xml:xsd:book")
    metadata = mbv.elements['ctx:metadata']
    assert(metadata.is_a?(REXML::Element))
    book = metadata.elements['rfe:book']
    assert(book.is_a?(REXML::Element))
    assert_equal(book.namespace('rfe'), "info:ofi/fmt:xml:xsd:book")
    assert_equal(book.attribute('schemaLocation').value, "info:ofi/fmt:xml:xsd:book http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:book")
    authors_cont = book.elements['rfe:authors']
    assert(authors_cont.is_a?(REXML::Element))
    author_cont = authors_cont.elements['rfe:author']
    assert(author_cont.is_a?(REXML::Element))    
    assert_equal(author_cont.elements['rfe:aulast'].get_text.value, "Chomsky")
    assert_equal(author_cont.elements['rfe:auinit'].get_text.value, "N")
    btitle = book.elements['rfe:btitle']
    assert(btitle.is_a?(REXML::Element))    
    assert_equal(btitle.get_text.value, "Minimalist Program")
    genre = book.elements['rfe:genre']
    assert(genre.is_a?(REXML::Element))
    assert_equal(genre.get_text.value, "book")
    date = book.elements['rfe:date']
    assert(date.is_a?(REXML::Element))
    assert_equal(date.get_text.value, "1995")    
    pub = book.elements['rfe:pub']
    assert(pub.is_a?(REXML::Element))
    assert_equal(pub.get_text.value, "The MIT Press")    
    place = book.elements['rfe:place']
    assert(place.is_a?(REXML::Element))
    assert_equal(place.get_text.value, "Cambridge, Mass")    
    place = book.elements['rfe:place']
    assert(place.is_a?(REXML::Element))
    assert_equal(place.get_text.value, "Cambridge, Mass")        
    isbn = book.elements['rfe:isbn']
    assert(isbn.is_a?(REXML::Element))
    assert_equal(isbn.get_text.value, "0262531283")       
    id = rfe.elements['ctx:identifier']
    assert(id.is_a?(REXML::Element))
    assert_equal(id.get_text.value, "urn:isbn:0262531283")

    rfr = ctx_obj.elements["ctx:referrer"]
    assert(rfr.is_a?(REXML::Element))    
    id = rfr.elements['ctx:identifier']
    assert(id.is_a?(REXML::Element))
    assert_equal(id.get_text.value, "info:sid/ebookco.com:bookreader") 
    
    svc = ctx_obj.elements["ctx:service-type"]
    assert(svc.is_a?(REXML::Element))
    mbv = svc.elements['ctx:metadata-by-val']
    assert(mbv.is_a?(REXML::Element))
    fmt = mbv.elements['ctx:format']
    assert(fmt.is_a?(REXML::Element))
    assert_equal(fmt.get_text.value, "info:ofi/fmt:xml:xsd:sch_svc")
    metadata = mbv.elements['ctx:metadata']
    assert(metadata.is_a?(REXML::Element))
    abstract = metadata.elements['svc:abstract']
    assert(abstract.is_a?(REXML::Element))
    assert_equal(abstract.namespace('svc'), "info:ofi/fmt:xml:xsd:sch_svc")
    
    assert_equal(abstract.get_text.value, "yes")
    #assert_match("svc_val_fmt=#{CGI.escape("info:ofi/fmt:kev:mtx:sch_svc")}", ctx.kev)
    #assert_match("svc.abstract=yes", ctx.kev)    
    
    #xml = File.new(data["context_objects"]["xml_doc"]).read
    #ctx = OpenURL::ContextObject.new_from_xml(xml)  
    #self.test_xml_values(ctx)    
  end


  # deep_copy and import_context_object should NOT result in
  # any shared objects between the two co's. 
  def test_no_shared_objects_on_copy
    require 'yaml'
    data = YAML.load_file('test/test.yml')
    ctx_orig = OpenURL::ContextObject.new_from_kev(data["context_objects"]["kev"])

    ctx_deep_copied = ctx_orig.deep_copy

    test_not_shared_objects( ctx_orig, ctx_deep_copied )

    ctx_with_imported_data = 
      OpenURL::ContextObject.new_from_context_object( ctx_orig )
    
    test_not_shared_objects( ctx_orig, ctx_with_imported_data )
    
  end
  
  
  def test_to_hash
    require 'yaml'
    kev = YAML.load_file('test/test.yml')["context_objects"]["kev"]

    ctx = OpenURL::ContextObject.new_from_kev(kev)
    rft_metadata = ctx.referent.metadata
    rfe_metadata = ctx.referringEntity.metadata
    hash = ctx.to_hash
    
    ["btitle", "genre", "aulast", "auinit", "date", "pub", "place"].each do | rft_key|
      assert_equal( hash["rft." + rft_key], rft_metadata[rft_key])
    end
    
    ["btitle", "genre", "aulast", "date", "pub", "place", "isbn"].each do |rfe_key|
      assert_equal( hash ["rfe." + rfe_key], rfe_metadata[rfe_key])
    end

    assert_equal("yes", hash["svc.abstract"] )
    
    # ids end up as arrays
    assert ( hash["rfr_id"].include?('info:sid/ebookco.com:bookreader'))
    assert( hash["rfe_id"].include?("urn:isbn:0262531283") )

    # Don't understand what this is supposed to be, not sure if this is right.
    assert_equal( "info:ofi/fmt:kev:mtx:book", hash["rft_val_fmt"])
    assert_equal("info:ofi/fmt:kev:mtx:book", hash["rfe_val_fmt"])


    
    assert_equal("info:ofi\/fmt:kev:mtx:ctx", hash["url_ctx_fmt"])
    assert_equal("2003-04-11T10:08:30TZD", hash["ctx_tim"])
    # Don't understand what this one means. 
    assert_equal("10_8", hash["ctx_id"])
    assert_match("Z39.88-2004", hash["ctx_ver"])
    assert_match("info:ofi/enc:UTF-8", hash["ctx_enc"])
  end


  
  def test_kev
    require 'yaml'
    data = YAML.load_file('test/test.yml')
    ctx = OpenURL::ContextObject.new_from_kev(data["context_objects"]["kev"])
    # Make sure the KEV output is displaying things properly
    assert_match(/ctx_ver=Z39\.88\-2004/,ctx.kev)
    assert_match("rft.btitle=#{CGI.escape("Dépendances et niveaux de représentation en syntaxe")}",ctx.kev)
    assert_match("rfe.btitle=#{CGI.escape("Minimalist Program")}",ctx.kev)
    assert_match("rft.genre=book",ctx.kev)
    assert_match("rfe.genre=book",ctx.kev)
    assert_match("rft.aulast=Vergnaud",ctx.kev)
    assert_match("rfe.aulast=Chomsky",ctx.kev)
    assert_match("rft.auinit=J.-R",ctx.kev)
    assert_match("rfe.auinit=N",ctx.kev)
    assert_match("rft.date=1985",ctx.kev)
    assert_match("rfe.date=1995",ctx.kev)
    assert_match("rft.pub=Benjamins",ctx.kev)
    assert_match("rfe.pub=The+MIT+Press",ctx.kev)    
    assert_match("rft.place=Amsterdam%2C+Philadelphia",ctx.kev)
    assert_match("rfe.place=Cambridge%2C+Mass",ctx.kev)
    assert_match("rfe_id=#{CGI.escape('urn:isbn:0262531283')}", ctx.kev)
    assert_match("rfe.isbn=0262531283", ctx.kev)
    assert_match("rfr_id=#{CGI.escape('info:sid/ebookco.com:bookreader')}", ctx.kev)    
    assert_match("rft_val_fmt=#{CGI.escape("info:ofi/fmt:kev:mtx:book")}", ctx.kev)
    assert_match("rfe_val_fmt=#{CGI.escape("info:ofi/fmt:kev:mtx:book")}", ctx.kev)
    assert_match("svc_val_fmt=#{CGI.escape("info:ofi/fmt:kev:mtx:sch_svc")}", ctx.kev)
    assert_match("svc.abstract=yes", ctx.kev)
    assert_match("url_ctx_fmt=#{CGI.escape("info:ofi\/fmt:kev:mtx:ctx")}", ctx.kev)
    assert_match("ctx_tim=#{CGI.escape("2003-04-11T10:08:30TZD")}",ctx.kev)
    assert_match("ctx_id=10_8",ctx.kev)
    assert_match("ctx_ver=Z39.88-2004",ctx.kev)
    assert_match("ctx_enc=#{CGI.escape("info:ofi/enc:UTF-8")}", ctx.kev)
  end
  
  def test_kev_01_pid
      kev = "sid=CSA:eric-set-c&pid=%3CAN%3EED492558%3C%2FAN%3E%26%3CPY%3E2004%3C%2FPY%3E%26%3CAU%3EHsu%2C%20Jeng-yih%20Tim%3C%2FAU%3E&date=2004&genre=proceeding&aulast=Hsu&aufirst=Jeng-yih&auinitm=T&title=Reading%20without%20Teachers%3A%20Literature%20Circles%20in%20an%20EFL%20Classroom"   
      ctx = OpenURL::ContextObject.new_from_kev(kev) 
      assert_equal("<AN>ED492558</AN>&<PY>2004</PY>&<AU>Hsu, Jeng-yih Tim</AU>", ctx.referent.private_data)
  end
  
  
  protected
  
  # Make sure ctx1 and ctx2 don't share the same data objects.
  # If they did, a change to one would change the other.
  def test_not_shared_objects(ctx1, ctx2)
    assert_not_equal( ctx1.referent.object_id, ctx2.referent.object_id );
    assert_not_equal( ctx1.referent.metadata.object_id, ctx2.referent.metadata.object_id )
    
    original_ref_title = ctx1.referent.metadata['title']
    new_title = "new test title"
    # just ensure new uniqueness
    new_title += original_ref_title if original_ref_title 
    
    ctx1.referent.set_metadata('title', new_title)

    # That better not have changed ctx2

    assert_not_equal( new_title, ctx2.referent.metadata['title'])
    
    # Now fix first title back to what it was originally, to have no
    # side-effects
    ctx1.referent.set_metadata('title', original_ref_title )
  end
  
  def test_kev_values(ctx)    
    assert_equal(ctx.referent.format, 'book')
    assert_equal(ctx.referent.class, OpenURL::Book)
    assert_equal(ctx.referent.metadata['btitle'], "Dépendances et niveaux de représentation en syntaxe")    
    assert_equal(ctx.referent.metadata['genre'], 'book')
    assert_equal(ctx.referent.metadata['aulast'], 'Vergnaud')
    assert_equal(ctx.referent.metadata['auinit'], 'J.-R')
    assert_equal(ctx.referent.metadata['date'], '1985')
    assert_equal(ctx.referent.metadata['pub'], 'Benjamins')
    assert_equal(ctx.referent.metadata['place'], "Amsterdam, Philadelphia")
    assert_equal(ctx.referringEntity.identifier, 'urn:isbn:0262531283')
    assert_equal(ctx.referringEntity.identifiers[0], 'urn:isbn:0262531283')
    assert_equal(ctx.referringEntity.format, 'book')
    assert_equal(ctx.referringEntity.class, OpenURL::Book)
    assert_equal(ctx.referringEntity.metadata['genre'], 'book')  
    assert_equal(ctx.referringEntity.metadata['aulast'], 'Chomsky')
    assert_equal(ctx.referringEntity.metadata['auinit'], 'N')
    assert_equal(ctx.referringEntity.metadata['btitle'], 'Minimalist Program')
    assert_equal(ctx.referringEntity.metadata['isbn'], '0262531283')
    assert_equal(ctx.referringEntity.metadata['date'], '1995')    
    assert_equal(ctx.referringEntity.metadata['pub'], 'The MIT Press')
    assert_equal(ctx.referringEntity.metadata['place'], 'Cambridge, Mass')
    assert_equal(ctx.serviceType[0].format, 'sch_svc')
    assert_equal(ctx.serviceType[0].metadata['abstract'], 'yes')
    assert_equal(ctx.referrer.identifier, 'info:sid/ebookco.com:bookreader')
    assert_equal(ctx.referrer.identifiers[0], 'info:sid/ebookco.com:bookreader')
    
    # Check administrative values
    assert_equal(ctx.admin["ctx_tim"]["value"], "2003-04-11T10:08:30TZD")
    assert_equal(ctx.admin["ctx_id"]["value"], "10_8")
    assert_equal(ctx.admin["ctx_enc"]["value"], "info:ofi/enc:UTF-8")
    assert_equal(ctx.admin["ctx_ver"]["value"], "Z39.88-2004")
  end
  
  def test_kev_hybrid_values(ctx)    
    assert(ctx.referrer.identifiers.index('info:sid/myid.com:mydb').is_a?(Fixnum))
    assert(ctx.referent.identifiers.index('info:doi/10.1126/science.275.5304.1320').is_a?(Fixnum))
    assert(ctx.referent.identifiers.index('info:pmid/9036860').is_a?(Fixnum))
    assert_match(/info:doi\/10\.1126\/science\.275\.5304\.1320|info:pmid\/9036860/, ctx.referent.identifier)
    assert_equal(ctx.referent.format, 'journal')
    assert_equal(ctx.referent.metadata['atitle'], "Isolation of a common receptor for coxsackie B")    
    assert_equal(ctx.referent.metadata['jtitle'], "Science")  
    assert_equal(ctx.referent.metadata['genre'], 'article')
    assert_equal(ctx.referent.metadata['aulast'], 'Bergelson')
    assert_equal(ctx.referent.metadata['auinit'], 'J')
    assert_equal(ctx.referent.metadata['date'], '1997')
    assert_equal(ctx.referent.metadata['volume'], '275')
    assert_equal(ctx.referent.metadata['spage'], '1320')
    assert_equal(ctx.referent.metadata['epage'], '1323')
    
    # Check administrative values
    assert_equal(ctx.admin["ctx_enc"]["value"], "info:ofi/enc:UTF-8")
    assert_equal(ctx.admin["ctx_ver"]["value"], "Z39.88-2004")
  end  
  
  def test_kev_01_values(ctx)    
    assert(ctx.referrer.identifiers.index('info:sid/myid:mydb').is_a?(Fixnum))
    assert(ctx.referent.identifiers.index('info:doi/10.1126/science.275.5304.1320').is_a?(Fixnum))    
    assert(ctx.referent.identifiers.index('info:pmid/9036860').is_a?(Fixnum))    
    assert_match(/info:doi\/10\.1126\/science\.275\.5304\.1320|info:pmid\/9036860/, ctx.referent.identifier)
    assert_equal(ctx.referent.format, 'journal')
    assert_equal(ctx.referent.metadata['atitle'], "Isolation of a common receptor for coxsackie B")    
    assert_equal(ctx.referent.metadata['title'], "Science")  
    assert_equal(ctx.referent.metadata['genre'], 'article')
    assert_equal(ctx.referent.metadata['aulast'], 'Bergelson')
    assert_equal(ctx.referent.metadata['auinit'], 'J')
    assert_equal(ctx.referent.metadata['date'], '1997')
    assert_equal(ctx.referent.metadata['volume'], '275')
    assert_equal(ctx.referent.metadata['spage'], '1320')
    assert_equal(ctx.referent.metadata['epage'], '1323')
    
    # Check administrative values
    assert_equal(ctx.admin["ctx_enc"]["value"], "info:ofi/enc:UTF-8")
    assert_equal(ctx.admin["ctx_ver"]["value"], "Z39.88-2004")
  end    
  
  def test_xml_values(ctx)    
    assert(ctx.referent.is_a?(OpenURL::Journal))
    assert(ctx.referrer.identifiers.index('info:sid/metalib.com:PUBMED').is_a?(Fixnum))
    assert(ctx.referent.identifiers.index('info:doi/10.1364/OL.29.000017').is_a?(Fixnum))
    assert(ctx.referent.identifiers.index('info:pmid/14719646').is_a?(Fixnum))
    assert_match(/info:doi\/10\.1364\/OL\.29\.000017|info:pmid\/14719646/, ctx.referent.identifier)
    assert(ctx.referringEntity.identifiers.index('info:doi/10.1063/1.1968421').is_a?(Fixnum))
    assert_equal(ctx.referent.format, 'journal')
    assert_equal(ctx.referent.metadata['atitle'], "Temperature dependence of Brillouin frequency, power, and bandwidth in panda, bow-tie, and tiger polarization-maintaining fibers.")    
    assert_equal(ctx.referent.metadata['stitle'], "Opt Lett")      
    assert_equal(ctx.referent.metadata['jtitle'], "Optics letters")
    assert_equal(ctx.referent.metadata['issn'], "0146-9592")
    assert_equal(ctx.referent.metadata['aulast'], 'Yu')
    assert_equal(ctx.referent.metadata['aufirst'], 'Qinrong')
    assert_equal(ctx.referent.metadata['date'], '2004-12-31')
    assert_equal(ctx.referent.metadata['volume'], '29')
    assert_equal(ctx.referent.metadata['issue'], '1')
    assert_equal(ctx.referent.metadata['pages'], '17/18')
    assert_equal(ctx.referent.metadata['spage'], '17')
    assert_equal(ctx.referent.metadata['epage'], '9')
    assert_equal(ctx.referent.authors.length, 3)
    assert_equal(ctx.referent.authors[1].aulast, "Bao")
    assert_equal(ctx.referent.authors[2].aulast, "Chen")
    assert_equal(ctx.referent.reference["format"], "http://www.metalib.com/by_ref_info.xsd")
    assert_equal(ctx.referent.reference["location"], "http://www.metalib.com/V?func=get_doc&doc_number=00261648")
    # Check administrative values
    assert_equal(ctx.admin["ctx_tim"]["value"], "2004-01-16T12:13:00Z")
    assert_equal(ctx.admin["ctx_id"]["value"], "123")
    assert_equal(ctx.admin["ctx_enc"]["value"], "info:ofi/enc:UTF-8")
    assert_equal(ctx.admin["ctx_ver"]["value"], "Z39.88-2004")
  end   

  def test_oai_dc_values(ctx)
    assert(ctx.referent.is_a?(OpenURL::DublinCore))
    assert_equal(ctx.referent.identifier, "info:doi/10.1086/508789")
    assert_equal(ctx.referent.metadata["title"], ["Resurrection and Appropriation: Reputational Trajectories, Memory Work, and the Political Use of Historical Figures"])
    assert_equal(ctx.referent.metadata["creator"], ["Robert S. Jansen"])
    assert_equal(ctx.referent.publisher, ["The University of Chicago Press"])
    assert_equal(ctx.referent.date, ["2007-02-27T13:27:58Z"])
    assert_equal(ctx.referent.rights, ["&copy; 2007 by The University of Chicago. All rights reserved."])
    assert_equal(ctx.referent.description, ["<P>The Zapatistas and Sandinistas both invoked historical figures in their rhetoric, but they did so in very different ways. This variation is explained by a model of path-dependent memory work that is sensitive to how previous memory struggles enable and constrain subsequent uses of historical figures. Specifically, previous struggles produce distinct reputational trajectories that condition the potential utility of different modes of memory work. The cases illustrate two reputational trajectories, which are situated within a broader field of mnemonic possibilities. This article offers a provisional baseline for comparing contested memory projects and supplies a framework for analyzing the opportunities and constraints by which reputational trajectories condition memory work. It builds on a recent processual emphasis in the collective memory literature and suggests that the contentious politics literature needs to historicize its conception of culture and take seriously the operation of constraints on symbolic work.</P>", "10.1086/508789"])
    assert_equal(ctx.referent.source, ["American Journal of Sociology, Volume 112 (2007), P. 953-1007"])
    assert_equal(ctx.referent.metadata["identifier"], ["http://www.journals.uchicago.edu/cgi-bin/resolve?id=doi:10.1086/508789"])
    assert_equal(ctx.referent.metadata["format"], ["application/html/pdf"])
    assert_equal(ctx.referent.metadata["lang"], ["English"])
    assert_equal(ctx.referent.metadata["type"], ["journal article"])
  end
  
  def test_marc_values(ctx)
    assert(ctx.referent.is_a?(OpenURL::Marc))
    assert(ctx.referent.marc.is_a?(MARC::Record))
    assert_equal(ctx.referent.marc.leader, "01142cam  2200301 a 4500")
    assert_equal(ctx.referent.marc['001'].value.strip, "92005291")
  end


    
end

