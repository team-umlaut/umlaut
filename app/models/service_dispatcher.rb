# ServiceDispatcher provides a framework for sending off an 
# openurl context object to a variety of services and getting 
# back a standard response which can be rendered in views. 
# 
# The services that can be added to the dispatcher are listed in 
# the app/models/dispatch_services directory.

class ServiceDispatcher
	attr_accessor :services
  def initialize
    @services = []
  end

  # pass in a service instance to add to the list of services
  # to run when a context_object is dispatched

  def add_service(service)
    raise "not a valid service" if not service.kind_of? DispatchService
    @services << service
  end

  # alias for add_service

  def <<(service)
    add_service(service)
  end

  # runs a context object over a defined set of dispatch services 
  # and collects the data into a single response which is returned

  def dispatch(context_object)
    # create a response to fill up
    response = DispatchResponse.new
    for service in @services
      service.handle context_object, response
    end
    unless service.kind_of? ServiceBundle
      puts service.class
      response.dispatched_services[service.identifier.to_sym] = service
    end
    return response
  end
  
  def add_identifier_lookups(context_object)
    idlookup = []
    [context_object.referent, context_object.referrer, context_object.referringEntity].each { | ent |
	    unless ent.identifier.nil?
		    idlookup << IdentifierLookupService.new(ent)
		   end
    }
		@services << ServiceBundle.new(idlookup) 	
  end
  
  def get_link_resolvers(collection)
  	resolvers = []
  	collection.institutions.each_key { | institution | 
      collection.institutions[institution].link_resolvers.each { | link_resolver |
        resolvers << LinkResolverService.new(link_resolver)      
      }
    }
    return resolvers
  end
  
  def get_opacs(collection)  
  	opacs = []
  	collection.institutions.each_key { | institution |   	
      collection.institutions[institution].catalogs.each { | catalog |
        opacs << OpacService.new(catalog)    
      }
    }
    opacs << WorldcatService.new
    return opacs
  end
  
  def add_search_engines
  	@services << ServiceBundle.new([AmazonService.new, GoogleService.new, YahooService.new])
  end
  
  def add_social_bookmarkers
  	@services << ServiceBundle.new([ConnoteaService.new, YahooMyWebService.new, UnalogService.new])  
  end
end
