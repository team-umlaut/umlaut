class ContextObjectHandler
	require 'ropenurl'
	attr_accessor :context_object
	attr_reader :current, :id
	def initialize(args, session)
		@context_object = OpenURL::ContextObject.new
		@id = nil
		@current = false
		@store = ContextObjectReferentStore.new 		
		self.create_context_object(args, session)
		@context_object.set_administration_key('ctx_id', @id)		
	end
	
	def create_context_object(args, session)
		if args['res_id'] and (args['res_id'].to_i.to_s == args['res_id'])
			self.create_from_id(args['res_id'], session)
		else
			self.create_from_args(args, session)
		end
	end
	
	def create_from_id(id, session)
		@id = id
		request = Request.find_by_id(id)
		@context_object.referent = Marshal.load request.referent.referent
		if request.referrer
			@context_object.referrer.set_identifier(request.referrer.identifier)
		end
		if h = History.find_by_session_id_and_request_id(session.session_id, id)
		  if h.cached_response and h.created_at > 8.hours.ago
 			 @current = true
			end
		end
	end
	
	def create_from_args(args, session)
    args.delete("action")
  	args.delete("controller")
    args = args.select {|k,v| not v.nil? }
    @context_object.import_hash(args) 
		if match = @store.find_by_context_object(@context_object)
			rft = Referent.find_by_id(match[:id].to_i)
			rfr_id = nil
			unless @context_object.referrer.empty?
				rfr = Referrer.find_or_create_by_identifier(@context_object.referrer.identifier)
				rfr_id = rfr.id
			end
			request = Request.find_or_create_by_referent_id_and_referrer_id(rft.id, rfr_id)
  		if h = History.find_by_session_id_and_request_id(session.session_id, request.id)
  		  if h.cached_response and h.created_at > 8.hours.ago
   			 @current = true
  			end
  		end			
		else		
			request = Request.new
			unless @context_object.referrer.identifier.nil?
				rfr = Referrer.find_or_create_by_identifier(@context_object.referrer.identifier)
				if rfr.new_record?
					rfr.save
				end
				request.referrer = rfr
			end				
		end
		if request.new_record?
			request.save
		end
		@id = request.id
	end
	
	def store(dispatch_response)
		request = Request.find_by_id(@id)
		if request.referent
			request.referent.referent = Marshal.dump @context_object.referent
		else
			rft = Referent.new 
			rft.referent = Marshal.dump @context_object.referent
			rft.save
			request.referent = rft
		end
		unless @context_object.referrer.identifier.nil?
			request.referrer = Referrer.find_by_identifier(@context_object.referrer.identifier)
		end
		#request.response = Marshal.dump dispatch_response
    dispatch_response.subjects.each_key {| src |
      dispatch_response.subjects[src].each { | subj |
        unless src == "LCSH" or src == "PubMed" or src == "sfx"
          subj_type = 'tag'
        else
          subj_type = case src
                  when 'LCSH' then 'LCSH'
                  when 'PubMed' then 'MeSH'
                  when 'sfx' then 'SFX'
                  else 'tag'
          end
        end
        s = {:term=>subj, :authority=>subj_type, :source=>src.to_s}
        puts s.inspect
        request.referent.subjects.create(:term=>subj, :authority=>subj_type, :source=>src.to_s)

      }
    }

		request.save
		@store.save_to_store(@context_object, request.referent)		
	end

end
