class PrimoEnhancer < Service
  required_config_params :base_path

  def initialize(config)
    super(config)
    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)
  end

  # Standard method, used by background service updater. See Service docs. 
  def service_types_generated
    types = [ ServiceTypeValue[:referent_enhance], ServiceTypeValue[:cover_image] ]
    
    return types
  end
  
  def handle(request)
    # Extend OpenURL standard to take Primo Doc Id
    # Necessary for Primo Referrer
    primo_id = request.referent.metadata['primo']
    
    # Generic Primo Searcher.
    primo_searcher = Exlibris::Primo::Searcher.new(@base_path, nil, nil, nil)
    
    # Set Primo Searcher primo id
    primo_searcher.primo_id = primo_id

    # Enhance referent if primo id is present
    # to deal with annoying non-roman scripts issue
    unless primo_id.nil?
      unless primo_searcher.jtitle.empty?
        #Prefer SFX Journal titles so don't overwrite
        request.referent.enhance_referent('jtitle', primo_searcher.jtitle, true, false, { :overwrite => false })
        request.referent.enhance_referent('title', primo_searcher.jtitle, true, false, { :overwrite => false })
      end 
      unless primo_searcher.btitle.empty?
        request.referent.enhance_referent('btitle', primo_searcher.btitle)
        request.referent.enhance_referent('title', primo_searcher.btitle)
      end
      request.referent.enhance_referent('aulast', primo_searcher.aulast) unless primo_searcher.aulast.empty?
      request.referent.enhance_referent('aufirst', primo_searcher.aufirst) unless primo_searcher.aufirst.empty?
      request.referent.enhance_referent('aucorp', primo_searcher.aucorp) unless primo_searcher.aucorp.empty?
      request.referent.enhance_referent('au', primo_searcher.au) unless primo_searcher.au.empty?

      request.referent.enhance_referent('pub', primo_searcher.pub) unless primo_searcher.pub.empty?
      request.referent.enhance_referent('place', primo_searcher.place) unless primo_searcher.place.empty?

      request.referent.enhance_referent('oclcnum', primo_searcher.oclcid, true, false, { :overwrite => false })
      request.referent.enhance_referent('lccn', primo_searcher.lccn, true, false, { :overwrite => false })

      cover_image = primo_searcher.cover_image
      unless cover_image.empty?
        request.add_service_response({
          :service=>self, 
          :display_text => 'Cover Image',
          :key=> 'medium', 
          :url => cover_image, 
          :service_data => {:size => 'medium' }
        },
        [ServiceTypeValue[:cover_image]])
      end

    end
    return request.dispatched(self, true)
  end
end