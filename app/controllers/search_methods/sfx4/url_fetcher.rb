module SearchMethods
  module Sfx4
    module UrlFetcher
      # used by umlaut:load_sfx_urls task. Kind of hacky way of trying to extract
      # target URLs from SFX4. 
      def fetch_urls
        connection = az_title_klass.connection

        # Crazy crazy URLs to try to find PARSE_PARAMS in Sfx4 db that have a period in
        # them, so they look like they might be URLs. Parse params could be at target service
        # level, or at portfolio level; and could be in local overrides or in global kb. 
        # This is crazy crazy SQL to get this, sorry. Talking directly to SFX db isn't
        # a great idea, but best way we've found to get this for now. Might make more
        # sense to try to use the (very very slow) SFX export in the future instead. 
        sql = %{
          SELECT 
            COALESCE(LCL_SERVICE_LINKING_INFO.PARSE_PARAM,KB_TARGET_SERVICES.PARSE_PARAM) PARSE_PARAM
          FROM
            LCL_TARGET_INVENTORY		  	  
          JOIN sfxglb41.KB_TARGET_SERVICES
  		  		ON KB_TARGET_SERVICES.TARGET_ID = LCL_TARGET_INVENTORY.TARGET_ID
  		  	JOIN LCL_SERVICE_INVENTORY 
  		  		ON LCL_TARGET_INVENTORY.TARGET_ID = LCL_SERVICE_INVENTORY.TARGET_ID
  		  	LEFT OUTER JOIN LCL_SERVICE_LINKING_INFO
  				  ON 	LCL_SERVICE_INVENTORY.TARGET_SERVICE_ID =	LCL_SERVICE_LINKING_INFO.TARGET_SERVICE_ID
  				WHERE
  				  ( LCL_SERVICE_LINKING_INFO.PARSE_PARAM like '%.%' OR
  				    KB_TARGET_SERVICES.PARSE_PARAM like '%.%' )
  				 AND
  				  LCL_SERVICE_INVENTORY.ACTIVATION_STATUS='ACTIVE'	     
  				 AND
  				  LCL_TARGET_INVENTORY.ACTIVATION_STATUS = 'ACTIVE'		 

  		 UNION
  		     -- object portfolio parse param version
  		   		   SELECT
  		     COALESCE(LCL_OBJECT_PORTFOLIO_LINKING_INFO.PARSE_PARAM, KB_OBJECT_PORTFOLIOS.PARSE_PARAM) PARSE_PARAM
  		   FROM
  		     sfxglb41.KB_OBJECT_PORTFOLIOS
  		   JOIN LCL_SERVICE_INVENTORY
          ON KB_OBJECT_PORTFOLIOS.TARGET_SERVICE_ID = LCL_SERVICE_INVENTORY.TARGET_SERVICE_ID
  	     JOIN LCL_OBJECT_PORTFOLIO_INVENTORY
  	      ON KB_OBJECT_PORTFOLIOS.OP_ID = LCL_OBJECT_PORTFOLIO_INVENTORY.OP_ID
         left outer join  LCL_OBJECT_PORTFOLIO_LINKING_INFO
          ON KB_OBJECT_PORTFOLIOS.OP_ID = LCL_OBJECT_PORTFOLIO_LINKING_INFO.OP_ID        
  		   WHERE
  		    ( KB_OBJECT_PORTFOLIOS.PARSE_PARAM like '%.%' OR 
            LCL_OBJECT_PORTFOLIO_LINKING_INFO.PARSE_PARAM like '%.%' )
          AND LCL_OBJECT_PORTFOLIO_INVENTORY.ACTIVATION_STATUS = 'ACTIVE'        
          AND LCL_SERVICE_INVENTORY.ACTIVATION_STATUS='ACTIVE'
        }

        results =  connection.select_all(sql)

        urls = []
        results.each do |line|
          param_string = line["PARSE_PARAM"]

          # Try to get things that look sort of like URLs out. Brutal force,
          # sorry. 
          url_re = Regexp.new('(https?://\S+\.\S+)(\s|$)')
          urls.concat( param_string.scan( url_re ).collect {|matches| matches[0]} )                
        end      
        urls.uniq!
        return urls
      end
    end
  end
end
