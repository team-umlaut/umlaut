module ResolverRegistry
  class Resolver
    attr_reader :source, :base_url, :link_icon, :openurl_versions, 
      :community_profiles, :vendor, :identifiers, :namespaces, :genres, 
      :metadata_formats, :transports, :encodings, :contextobject_formats, 
      :keyname, :contact_name, :contact_mailto, :link_text

    def initialize(resolver)
      @openurl_versions = []
      @community_profiles = []
      @identifiers = []
      @namespaces = []
      @genres = []
      @metadata_formats = []
      @transports = []
      @encodings = []
      @contextobject_formats = []
    
      self.parse_record(resolver)  
    end
    
    def parse_record(resolver)
      @source = resolver.elements['source'].get_text.value if resolver.elements['source'] and resolver.elements['source'].has_text?
      @base_url = resolver.elements['baseURL'].get_text.value if resolver.elements['baseURL'] and resolver.elements['baseURL'].has_text?
      @link_text = resolver.elements['linkText'].get_text.value if resolver.elements['linkText'] and resolver.elements['linkText'].has_text? 
      @link_icon = resolver.elements['linkIcon'].get_text.value if resolver.elements['linkIcon'] and resolver.elements['linkIcon'].has_text? 
      @contact_name = resolver.elements['contactName'].get_text.value if resolver.elements['contactName'] and resolver.elements['contactName'].has_text? 
      @contact_mailto = resolver.elements['contactMailto'].get_text.value if resolver.elements['contactMailto'] and resolver.elements['contactMailto'].has_text?     
      @vendor = resolver.elements['vendor'].get_text.value if resolver.elements['vendor'] and resolver.elements['vendor'].has_text?     
      @keyname = resolver.elements['keyname'].get_text.value if resolver.elements['keyname'] and resolver.elements['keyname'].has_text?     
      resolver.elements['OpenURLVersions'].elements.each { | version | 
        @openurl_versions << version.name
      }
      resolver.each_element('Z39.88-2004_CommunityProfile') { | profile | 
        @community_profiles << profile.get_text.value if profile.has_text?
      }    
      resolver.elements['OpenURL_0.1_Identifiers'].elements.each { | id |
        @identifiers << id.name
      }
      resolver.each_element('Z39.88-2004_namespace') { | namespace |
        @namespaces << namespace.get_text.value if namespace.has_text?
      }
      resolver.elements['OpenURL_0.1_genres'].elements.each { | genre |
        @genres << genre.name
      }    
      resolver.each_element('Z39.88-2004_metadataFormat') { | format |
        @metadata_formats << format.get_text.value if format.has_text?
      }
      resolver.each_element('Z39.88-2004_transport') { | transport | 
        @transports << transport.get_text.value if transport.has_text?
      }
      resolver.each_element('Z39.88-2004_encoding') { | encoding | 
        @encodings << encoding.get_text.value if encoding.has_text?
      }
      resolver.each_element('Z39.88-2004_contextObject') { | ctxobj_fmt |
        @contextobject_formats << ctxobj_fmt.get_text.value if ctxobj_fmt.has_text?
      }
    end
  end
end
