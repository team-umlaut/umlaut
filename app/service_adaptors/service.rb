# Services are defined from the config/umlaut_config/services.yml file.
# hey should have the following properties
# id : unique internal string for the service, unique in yml file
# display_name : user displayable string
# url : A base url of some kind used by specific service
# type : Class name of class found in lib/service_adaptors to be used for logic
# priority: 0-9 (foreground) or a-z (background) for order of service operation
#
# Specific service_adaptor classes may have specific addtional configuration,
# commonly including 'password' or 'api_key'.
# specific service can put " required_config_parms :param1, :param2"
# in definition, for requirement exception raising on initialize.
#
# = Service Sub-classes
# Can include required config params in the class definition, eg:
#     required_config_params :api_key, :base_url
#
# Should define #service_types_generated returning an array of
# ServiceTypeValues.  This is neccesary for the Service to be
# run as a background service, and have the auto background updater
# work.
#
# The vast majority of services are 'standard' services, however
# there are other 'tasks' that a service can be. Well, right now, one
# other, 'link_out_filter'. The services 'task' config property
# sets the task/function/hook of the service. Default is 'standard'.
#
# A standard service defines handle(request)
#
# A link_out_filter service defines link_out_filter(request, url). If service
# returns a new url from filter_url, that's the url the user will be directed
# to. If service returns original url or nil, original url will still be used. 
#
# See documentation at ServiceResponse regarding how a service generates
# ServiceResponses to respond to a user request. 
class Service
  attr_reader :priority, :service_id, :url, :task, :status, :name, :group
  attr_accessor :request
  @@required_params_for_subclass = {} # initialize class var

  # Some constants for 'function' values
  StandardTask = 'standard'
  LinkOutFilterTask = 'link_out_filter'

  
  def initialize(config)
    config.each do | key, val |
      self.instance_variable_set(('@'+key).to_sym, val)
    end

    # task defaults to standard
    @task ||= StandardTask

    # check required params, and throw if neccesary

    required_params = Array.new
    # Some things required for all services
    required_params << "priority"
    # Custom things for this particular sub-class
    
    required_params.concat( @@required_params_for_subclass[self.class.name] ) if @@required_params_for_subclass[self.class.name]
    required_params.each do |param|
      begin
          value = self.instance_variable_get('@' + param.to_s)
          # docs say it raises a nameerror if it doesn't exist, docs
          # lie. So we'll just raise one ourselves, and catch it, to
          # handle both cases.
          raise NameError if value.nil?          
      rescue NameError
      raise ArgumentError.new("Missing Service configuration parameter. Service type #{self.class} (id: #{self.service_id}) requires a config parameter named '#{param}'. Check your config/umlaut_services.yml file.")
      end      
    end    
  end

  # Must be implemented by concrete sub-class. return an Array of 
  # ServiceTypeValues constituting the types of ServiceResponses the service
  # might generate. Used by Umlaut infrastructure including the background
  # service execution scheme itslef, as well asxml services returning 
  # information on services in progress.
  #
  # Example for a service that only generates fulltext: 
  #    return [ ServiceTypeValue[:fulltext] ]
  def service_types_generated
    raise Exception.new("#{self.class}: service_types_generated() must be implemented by Service concrete sub-class!")
  end


  # Method that should actually be called to trigger the service.
  # Will check pre-emption. 
  def handle_wrapper(request)
    unless ( preempted_by(request) )
      return handle(request)
    else
      # Pre-empted, log and close dispatch record as 'succesful'.
      Rails.logger.debug("Service #{service_id} was pre-empted and not run.")
      return request.dispatched(self, true)
    end
  end
  
  # Implemented by sub-class. Standard response-generating services implement
  # this method to do their work, generate responses and/or metadata. 
  def handle(request)
    raise Exception.new("#{self.class}: handle() must be implemented by Service concrete sub-class, for standard services!")
  end

  # This method is implemented by a concrete sub-class meant to
  # fulfill the task:link_out_filter. Will be called when the user clicks
  # on a url that will redirect external to Umlaut. The link_out_filter
  # service has the ability to intervene and record and/or change
  # the url. link_out_filters are called in order of priority config param
  # assigned, 0 through 9.
  #
  # orig_url is the current url umlaut is planning on sending the user to.
  # service_type is the ServiceType object responsible for this url.
  # the third argument is reserved for future use an options hash. 
  def link_out_filter(orig_url, service_response, other_args = {})
    raise Exception.new("#{self.class}: #link_out_filter must be implemented by Service concrete sub-class with task link_out_filter!")
  end

  # Name of this service, like "Amazon", or "OCLC Worldcat". 
  # First tries to look up an i18n translation using #translate, if not
  # found, uses a @display_name set in this service, if still not found
  # uses service_id for lack of anything else. 
  def display_name    
    self.translate("display_name", :default => @display_name || self.service_id)
  end



  # Sub-class can call class method like:
  #  required_config_params  :symbol1, :symbol2, symbol3
  # in class definition body. List of config parmas that
  # are required, exception will be thrown if not present. 
  def self.required_config_params(*params)
    params.each do |p|
      # Key on name of specific sub-class. Since this is a class
      # method, that should be self.name
      @@required_params_for_subclass[self.name] ||= Array.new
      a = @@required_params_for_subclass[self.name]
      a.push( p ) unless a.include?( p )
    end
  end




 # This method is called by Umlaut when user clicks on a service response. 
 # Default implementation here just returns response['url']. You can
 # over-ride in a sub-class to provide custom implementation of on-demand
 # url generation. Second argument is the http request params sent
 # by the client, used for service types that take form submissions (eg
 # search_inside). 
 # Should return a String url.
 def response_url(service_response, submitted_params )
   url = service_response[:url]
   raise "No url provided by service response" if url.nil? || url.empty?
   return url
 end

 # Look up an i18n key scoped to this service, first under the unique ID of
 # the service, then under the service class name:
 # * First look for translation under `umlaut.services.#{service_id.underscore}.key`
 # * If not found, look for translation under `umlaut.services.#{service_class_name.underscore}`
 # * If still not found, pass in optional default, otherwise you'll get I18n
 #    configured failure behavior. 
 #
 # second arg is options that can be passed to standard I18n.t, including defaults
 # and template arguments. 
 def translate(key, options = {})
    # Modify/add options[:default] to look up under class name too
    options[:default] = [:"umlaut.services.#{self.class.name.underscore}.#{key}"].concat(Array( options[:default] ))

    I18n.t("umlaut.services.#{self.service_id.underscore}.#{key}", options)
 end

 # Pre-emption hashes specify a combination of existing responses or
 # service executions that can pre-empt this service. Can specify
 # a service, a response type (ServiceTypeValue), or a combination of both.
 #
 # service's preempted_by property can either be a single pre-emption hash,
 # or an array of pre-emption hashes. 
 #
 # Can also specify that pre-emption is only of a certain service type
 # generated by self.
 #
 # The Service base class will enforce pre-emption and not even run
 # a service at all *so long as self_type is nil or '*' *. If the pre-emption
 # only applies to certain types generated by the service and not the entire
 # execution of the service, the concrete service subclass must implement
 # logic to do that. Calling the preempted method with the second argument
 # set will be helpful in writing this logic. 
 #
 # A preemption hash has string keys:
 #    existing_service: id of service that will pre-empt this service.
 #                      If key does not exist or is "*", then not specified,
 #                      any service. (existing_type will be specified). 
 #    existing_type:  ServiceTypeValue name that pre-empts this
 #                    service. "+" means that the service specified
 #                    in existing_service must have generated some
 #                    response, but type does not matter. "*" means
 #                    that the service specified in existing_service
 #                    must have completed succesfully, but may not
 #                    have generated any responses.
 #    self_type:      If blank or "*", preemption applies to any running
 #                    of this service at all. If set to a ServiceTypeValue
 #                    name, pre-emption is only of certain types generated
 #                    by this service. 
 def preempted_by(uml_request, for_type_generated=nil)
   preempted_by = @preempted_by
   return false if preempted_by.nil?
   preempted_by = [preempted_by] unless preempted_by.kind_of?(Array)
   preemption = nil

   preempted_by.each do | hash |
      service = hash["existing_service"] || "*"
      other_type = hash["existing_type"] || "*"      
      self_type = hash["self_type"] || "*"

      next unless (self_type == "*" || self_type == for_type_generated)

      if (other_type == "*")
        # Need to check dispatched services instead of service_types,
        # as we pre-empt even if no services created. 
        preemption = 
        uml_request.dispatched_services.to_a.find do |disp|
          service == "*" || 
          (disp.service_id == service &&
            (disp.status ==  DispatchedService::Successful ))
        end
      else
        # Check service responses
        preemption = Request.connection_pool.with_connection do 
            uml_request.service_responses.to_a.find do |response|
            ( other_type == "*" || other_type == "+" ||
              response.service_type_value.name == other_type)  &&
            ( service == "*" ||
              response.service_id == service)         
          end
        end
      end
      break if preemption
   end
   return (! preemption.nil? )
 end
 
 # used by render_service_credits helper method, returns
 # a hash with keys being a human-displayable name of a third party
 # to give 'credit' to, and value being a URL (or nil) to link the
 # name to. 
 # computed from @credits config variable, or returns empty hash. 
 def credits
   @credits || {}
 end

  
end
