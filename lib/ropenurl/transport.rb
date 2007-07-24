module OpenURL

  class Transport
  	attr_accessor(:host, :context_objects, :extra_args)
  	attr_reader(:response, :request_string)
		def initialize(host, contextobject=nil)
			@host = host
			@context_objects = []
			if contextobject.class == OpenURL::ContextObject or @context_object.is_a?(Array)
				@context_objects.push(contextobject)
			end
			@url_ver = "Z39.88-2004"
			@response = nil
			@extra_args = {}
		end
		
		def add_context_object(contextobject)
			if contextobject.class == OpenURL::ContextObject or @context_object.is_a?(Array)
				@context_objects.push(contextobject)
			end			
		end
  	def remove_context_object(idx)
  		@context_objects.delete_at(idx)
  	end
  	
  	def transport_inline(idx=0)
      
			require 'open-uri'
      extras = ""
      @extra_args.each_key {|key|
        extras += "&"+key+"="+@extra_args[key]
      }
			open( @host+"?"+self.transport_metadata_get("info:ofi/fmt:kev:mtx:ctx")+extras+"&"+@context_objects[idx].kev ) do |r|
				@response = r.read
			end 		
  	end
  	def transport_by_ref(fmt, ref, method="GET")
  		md = self.transport_metadata_get(fmt)
  		if method == "GET"
  			require 'open-uri'
  			require 'cgi'
  			open(@host+"?"+md+"&url_ctx_ref="+CGI.escape(ref)) do |r|
  				@response = r.read
  			end
  		else
  			args = self.transport_metadata_post(fmt)
  			args["url_ctx_ref"] = ref
  			unless @extra_args.empty?
  				args = args.merge(@extra_args)
  			end  		
  			@response = self.post_http(args)  		
  		end
  	end
		
		def transport_by_val(method="POST", idx=0)
			if method == "GET"
  			require 'open-uri'
  			require 'cgi'
        extras = ""
        @extra_args.each_key {|key|
          extras += "&"+key+"="+@extra_args[key]
        }
        @request_string = @host+"?"+self.transport_metadata_get("info:ofi/fmt:kev:mtx:ctx")+extras+"&url_ctx_val="+CGI.escape(@context_objects[idx].kev)
  			open(@host+"?"+self.transport_metadata_get("info:ofi/fmt:kev:mtx:ctx")+extras+"&url_ctx_val="+CGI.escape(@context_objects[idx].kev) ) do |r|
  				@response = r.read
  			end
  		else
  			args = self.transport_metadata_post("info:ofi/fmt:xml:mtx:ctx")
  			unless @extra_args.empty?
  				args = args.merge(@extra_args)
  			end         
  			if @context_objects.length > 1
  				args["url_ctx_val"] = self.merge_context_objects
  			else
  				args["url_ctx_val"] = @context_objects[0].xml
  			end
 			  			
  			@response = self.post_http(args)  		
  		end			
		end
  	
  	def post_http(args)
		  require 'net/http'
		  require 'uri'		
		  r = Net::HTTP.post_form URI.parse(@host), args	
			return r.body		  
  	end

  	def transport_metadata_get(fmt)
  		require 'date'
  		require 'cgi'
  		return "url_ver=Z39.88-2004&url_ctx_fmt="+CGI.escape(fmt)+"&url_tim="+CGI.escape(DateTime.now().to_s)
  	end
  	
  	def transport_metadata_post(fmt)
  		return {"url_ver"=>"Z39.88-2004", "url_ctx_fmt"=>fmt, "url_tim"=>DateTime.now().to_s}
  	end
  end
end