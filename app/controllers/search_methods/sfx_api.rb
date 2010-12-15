module SearchMethods
  
  # NON-WORKING sketch of a search method that contacts SFX api directly.
  # Problem with this was that SFX is way too slow; SFX api didn't take
  # account of year/volume/issue when displaying multiple results anwyay,
  # so there wasn't that functionality benefit. It just wasn't worth it. 
  #
  # This code is basically copied and pasted from before the refactor,
  # it's not close to working yet, but is left for archival purposes
  # in case anyone wants to take a stab at it. 
  module SfxApi
    
    def find_by_title
        ctx = context_object_from_params
        search_results = []
  
        sfx_url = AppConfig.param("search_sfx_base_url")
        unless (sfx_url)      
          # try to guess it from our institutions
          instutitions = Institution.find_all_by_default_institution(true)
          instutitions.each { |i| i.services.each { |s| 
             sfx_url = s.base_url if s.kind_of?(Sfx) }}      
        end
              
        transport = OpenURL::Transport.new(sfx_url, ctx)
        transport.extra_args["sfx.title_search"] = params["sfx.title_search"]
        transport.extra_args["sfx.response_type"] = 'multi_obj_xml'
  
        
        transport.transport_inline
        
        doc = REXML::Document.new transport.response
        
        #client = SfxClient.new(ctx, resolver)
        
        doc.elements.each('ctx_obj_set/ctx_obj') { | ctx_obj | 
          ctx_attr = ctx_obj.elements['ctx_obj_attributes']
          next unless ctx_attr and ctx_attr.has_text?
          
          perl_data = ctx_attr.get_text.value
          search_results << Sfx.parse_perl_data( perl_data )
        } 
        return [search_results, doc.elements.length]     
    end

  end
end
