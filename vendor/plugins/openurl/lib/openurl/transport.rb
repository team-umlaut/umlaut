# encoding: UTF-8

require 'net/http'
require 'uri'		

module OpenURL  
  # The Transport class is intended to be used to deliver ContextObject objects
  # to an OpenURL enabled host.  Currently only HTTP is supported.  
  # Usage:
  # require 'openurl'  
  # include OpenURL
  # context_object = ContextObject.new_from_kev('ctx_enc=info%3Aofi%2Fenc%3AUTF-8&ctx_ver=Z39.88-2004&rft.genre=article&rft_id=info%3Adoi%2F10.1016%2Fj.ipm.2005.03.024&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Aarticle&url_ctx_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Actx&url_ver=Z39.88-2004')
  # transport = Transport.new('http://demo.exlibrisgroup.com:9003/lr_3', context_object)
  # transport.get
  # puts tranport.response
  
  class Transport
  	attr_accessor(:extra_args, :ctx_id)
  	attr_reader(:response, :request_string, :context_objects, :code, :message)
    
    # Creates the transport object which can be used to initiate
    # subsequent requests.  The contextobject argument can be an OpenURL 
    # ContextObject object, and array of ContextObjects or nil.  http_arguments 
    # set the Net::HTTP attributes: {:open_timeout=>3, :read_timeout=>5}, etc.
    
		def initialize(target_base_url, contextobject=nil, http_arguments={})      
			@uri = URI.parse(target_base_url)
			@context_objects = []
      self.add_context_object(contextobject) if contextobject
			@url_ver = "Z39.88-2004"			
			@extra_args = {}      
      @client = Net::HTTP.new(@uri.host, @uri.port)
      @client.open_timeout = (http_arguments[:open_timeout]||3)
      @client.read_timeout = (http_arguments[:read_timeout]||5)
		end
		
    # Can take either an OpenURL::ContextObject or an array of ContextObjects
    # to send to the Transport target
    
		def add_context_object(contextobject)
      
      if contextobject.is_a?(OpenURL::ContextObject)
        @context_objects << contextobject
      elsif contextobject.is_a?(Array)
        contextobject.each do | co |
          raise ArgumentError, "Each element in array much be an OpenURL::ContextObject!" unless co.is_a?(OpenURL::ContextObject)          
          @context_objects << co
        end      
      else 
        raise ArgumentError, "Argument must be a ContextObject or array of ContextObjects!, #{contextobject.class} sent."        
      end      	
		end
    
    # Accepts either a ContextObject or array index to remove from array being
    # sent to the Transport target
    
  	def remove_context_object(element)
      idx = case element.class
      when Fixnum then element
      when OpenURL::ContextObject then @context_objects.index(element)
      else raise ArgumentError, "Invalid argument for element"
      end
      @context_objects.delete_at(idx)
  	end
    
    # Perform an inline HTTP GET request.  Only one context object can be sent
    # via GET, so pass the index of the desired context object (defaults to the 
    # first)
    
    def get(idx=0)           
      self.parse_response(@client.get( self.get_path(idx)  ))      
    end

    # useful for debugging to have this factored out
    def get_path(idx=0)
      extra = ""
      @extra_args.each do | key, val |        
        extra << "&#{key}=#{val}"
      end
      return "#{@uri.path}?#{@context_objects[idx].kev}#{extra}"
    end
    
    # Sends an inline transport request.  YOu can specify which HTTP method
    # to use.  Since you can only send one context object per inline request, 
    # the second argument is the index of the desired context object.
    
    def transport_inline(method="GET", idx=0)
      return(self.get(idx)) if method=="GET"
      return(self.post({:inline=>true, :index=>idx})) if method=="POST"
    end
    
    # Sends an by-value transport request.  YOu can specify which HTTP method
    # to use.  Since a GET request is effectively the same as an inline request,
    # the index of which context object must be specified (defaults to 0).
    
		def transport_by_val(method="POST", idx=0)
      return(self.get(idx)) if method=="GET"
      return(self.post) if method=="POST"	
		end    
    
    # POSTs an HTTP request to the transport target.  To send an inline request,
    # include a hash that looks like: {:inline=>true, :index=>n} (:index defaults
    # to 0.  Transport.post must be used to send multiple context objects to a
    # target.
    
    def post(args={})
      # Inline requests send the context object as a hash
      if args[:inline]
        self.parse_response(self.post_http(@context_objects[(args[:index]||0)].to_hash.merge(@extra_args.merge({"url_ctx_fmt"=>"info:ofi/fmt:kev:mtx:ctx"}))))        
        return
      end            
      ctx_hash = {"url_ctx_fmt" => "info:ofi/fmt:xml:xsd:ctx"}
      # If we're only sending one context object, use that, otherwise concatenate
      # them.
      if @context_objects.length == 1
        ctx_hash["url_ctx_val"] = @context_objects[0].xml
      else
        ctx_hash["url_ctx_val"] = self.merge_context_objects
      end
      @context_objects[0].admin.each do | key, hsh |
        ctx_hash[key] = hsh["value"]
      end         
      
      self.parse_response(self.post_http(ctx_hash.merge(@extra_args)))      
    end
    
    # For a multiple context object request, takes the first context object in
    # the context_objects attribute, and adds the other context objects to it, 
    # under /ctx:context-objects/ctx:context-object and serializes it all as XML.
    # Returns a string of the XML document
    
    def merge_context_objects
      ctx_doc = REXML::Document.new(@context_objects[0].xml)
      root = ctx_doc.root
      @context_objects.each do | ctx |
        next if @context_objects.index(ctx) == 0
        c_doc = REXML::Document.new(ctx.xml)
        c_elm = c_doc.elements['ctx:context-objects/ctx:context-object']
        root.add_element(c_elm)
      end      
      return ctx_doc.to_s
    end
    
    # Deprecated.  Set by-reference in OpenURL::ContextObject and use .get or 
    # .post
    
  	def transport_by_ref(fmt, ref, method="GET")
  		md = "url_ver=Z39.88-2004&url_ctx_fmt="+CGI.escape(fmt)+"&url_tim="+CGI.escape(DateTime.now().to_s)
  		if method == "GET"  	
        parse.response(@client.get("#{@uri.path}?#{md}&url_ctx_ref="+CGI.escape(ref)))
  		else
  			args = {"url_ver"=>"Z39.88-2004",
          "url_ctx_fmt"=>fmt,
          "url_tim"=>DateTime.now().to_s,
          "url_ctx_ref" => ref}  			
  			args = args.merge(@extra_args) unless @extra_args.empty?
  				  			
  			self.parse_response(self.post_http(args))
  		end
  	end		  		
    
    protected
    
    # Reads the HTTP::Response object and sets the response, code and message
    # attributes
    
    def parse_response(response)
      @response = response.body
      @code = response.code
      @message = response.message
    end 

    # Sends the actual POST request.
    
  	def post_http(args)
		  return(Net::HTTP.post_form @uri, args)			
  	end    
  end
end