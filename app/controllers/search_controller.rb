# The search controller handles searches fo manually entered citations,
# or possibly ambiguous citations generally. It also provides an A-Z list.
#
# As source of this data, it can either use an Umlaut local journal index
# (supplemented by the SFX API for date-sensitive querries),
# or it can instead talk directly to the SFX db (still supplemented
# by the API).  Whether it uses the journal index depends on
# the value of the app config parameter use_umlaut_journal_index.
#
# The umlaut local journal index is probably not quite working at the moment.
#
# Otherwise, it'll try to talk to the SFX db directly using
# a database config named 'sfx_db' defined in config/database.yml 
#
# In either case, for talking to SFX API, how does it know where to find the
# SFX to talk to? You can either define it in app config param
# 'search_sfx_base_url', or if not defined there, the code will try to find
# by looking at default Institutions for SFX config info.  
class SearchController < ApplicationController
  #require 'open_url'

  @@search_batch_size = 20
  @@az_batch_size = 20
  @@autocomplete_limit = 15
  
  layout AppConfig.param("search_layout","search_basic"), :except => [ :opensearch, :opensearch_description ]

  before_filter :normalize_params
  
  def index
    # Oddly, render doesn't call the action method.
    journals()
  	render :action=>'journals'
  end  
  
  def journals
    #fall through to view
    @submit_hash = params["umlaut.display_coins"] ? {:controller=>'resolve', :action=>'display_coins'} : {:controller=>'search', :action=>'journal_search'}
  end


  def books
     @submit_action = params["umlaut.display_coins"] ? "display_coins" : "index"
  end

  
  # @search_results is left as an array of ContextObject objects.
  # Or, redirect to resolve action for single hit.
  # O hit also redirects to resolve action, as per SFX behavior--this
  # gives a catalog lookup and an ILL form for 0-hit. 
  # param umlaut.title_search_type (aka sfx.title_search) 
  # can be 'begins', 'exact', or 'contains'. Other
  # form params should be OpenURL, generally
  def journal_search
    # for reasons I can't tell, our JS on IE ends up putting some
    # newlines in the object_id, which messes us all up.
    params['rft.object_id'].strip! if params['rft.object_id']
    
    @batch_size = @@search_batch_size
    @page = 1  # page starts at 1 
    @page = params['page'].to_i if params['page']
    @start_result_num = (@page * @batch_size) - (@batch_size - 1)
    
    @search_context_object  = context_object_from_params
    # It's a journal, make it so
    @search_context_object.referent.set_format('journal')
    @search_context_object.referent.set_metadata('genre', 'journal')
            
    if (params["umlaut.title_search_type"] == 'exact' ||
        ! params["rft.object_id"].blank? ||
        ! params["rft.issn"].blank? ||
        ! params["rft_id"].blank? )
      # If we have an exact-type 'search', just switch to 'resolve' action
      redirect_to url_for_with_co( {:controller => 'resolve'}, @search_context_object ) 
      
      # don't do anything else.
      return
    elsif (params['rft.jtitle'].blank?)
      #Bad, error condition. If we don't have any of that other stuff above,
      # we need a title!  Send them back to entry page with an error message.
      flash[:error] = "You must enter a journal title or other identifying information."
      redirect_to :controller=>:search, :action=>:index
      return
    elsif ( @use_umlaut_journal_index )
      # Not exact search, and use local index. .
      self.find_via_local_title_source()
    else
      # Talk to SFX via direct db.
      self.find_by_title_via_sfx_db()
    end

    # Calculate end-result number for display
    @end_result_num = @start_result_num + @batch_size - 1
    if @end_result_num > @hits
      @end_result_num = @hits
    end
    
    # Supplement them with our original context object, so date/vol/iss/etc
    # info is not lost.
    #orig_metadata = search_co.referent.metadata
    #@display_results.each do | co |
    #  orig_metadata.each do |k,v|        
        # Don't overwrite, just supplement
    #    co.referent.set_metadata(k, v) unless co.referent.get_metadata(k) || v.blank?
    #  end
    #end
    
    if (@page == 1) && (@display_results.length == 1)
      # If we narrowed down to one result redirect
      # to resolve action.
      redirect_to( url_for_with_co({:controller => 'resolve'}, @display_results[0]) )      
    elsif (@display_results.length == 0)
      # 0 hits, do it too.
      redirect_to(  url_for_with_co({:controller => 'resolve'}, @search_context_object) )            
    end

  end


  def journal_list

  
        
    @batch_size = @@az_batch_size
    @page = 1  # page starts at 1 
    @page = params['page'].to_i if params['page']
    (params['page'] = @page =  1) if @page == 0 # non-numeric will to_i to 0
    @start_result_num = (@page * @batch_size) - (@batch_size - 1)

    if ( @use_umlaut_journal_index)
      @hits = Journal.count(:conditions=>["page = ?", params[:id].downcase])
      
      journals = Journal.find_all_by_page(params[:id].downcase, :order=>'normalized_title', :limit=>@batch_size, :offset=>@batch_size*(@page-1))
      # convert to context objects for display
      @display_results = journals.collect { |j| j.to_context_object }
    else
      # Talk to the SFX AZ index
      
      joins = " inner join AZ_LETTER_GROUP_VER3 as lg on AZ_TITLE_VER3.AZ_TITLE_VER3_ID = lg.AZ_TITLE_VER3_ID"
      # Need a special condition for 0-9
      if ( params[:id] == '0-9')
        conditions = ["AZ_PROFILE=? AND lg.AZ_LETTER_GROUP_VER3_NAME IN ('0','1','2','3','4','5','6','7','8','9')",
        sfx_az_profile]
      else
        conditions = ["AZ_PROFILE=? AND lg.AZ_LETTER_GROUP_VER3_NAME = ?", 
        sfx_az_profile,
        params[:id].upcase]
      end

      @hits = SfxDb::AzTitle.count(:joins => joins,
            :conditions => conditions)


      # Sorry this find is so crazy, trying to manage to do it
      # efficiently and get what we need in large SFX db. 
      # For crazy nested include below, see:
      # http://snippets.dzone.com/posts/show/2089
      az_titles = SfxDb::AzTitle.find(:all, 
        :joins => joins,
        :conditions => conditions,
        :limit => @batch_size,
        :offset=>@batch_size*(@page -1),
        :order=>'TITLE_SORT',
        :include=>[{:object => [:publishers, :titles] }])
        
      # Convert to context objects
      @display_results = az_titles.collect do | azt | 
        co = azt.to_context_object
        co.referrer.add_identifier('info:sid/umlaut.code4lib.org:azlist')
        co
      end
             
      
    end

    # Calculate end-result number for display
    @end_result_num = @start_result_num + @batch_size - 1
    if @end_result_num > @hits
      @end_result_num = @hits
    end
    
    # Use our ordinary search displayer to display
    # It'll notice the action and do just a bit of special stuff.
    render(:template => "search/journal_search")
  end  

  
  
  

  # Should return an array of hashes, with each has having :title and :object_id
  # keys. Can come from local journal index or SFX or somewhere else.
  # :object_id is the SFX rft.object_id, and can be blank. (I think it's SFX
  # rft.object_id for local journal index too)
  def auto_complete_for_journal_title
   # Don't search on blank query.
   query = params['rft.jtitle']
   unless ( query.blank? )
    if (@use_umlaut_journal_index)
      @titles = Journal.find_all_by_contents(:all, :conditions => ["contents = ?","alternate_titles:*"+query+"*"], :limit=>@@autocomplete_limit).collect {|j| {:object_id => j[:object_id], :title=> j.title }   }
    else      
  
      # Use V3 list instead.
      @titles = SfxDb::AzTitle.find(:all, 
      :conditions => ["AZ_PROFILE = ? AND TITLE_DISPLAY like ?", 
        sfx_az_profile,
        "%" + query + "%"],
      :limit => @@autocomplete_limit).collect {|to| {:object_id => to.OBJECT_ID, :title=>to.TITLE_DISPLAY}
      }
      
    end
   end
   render :partial => 'journal_titles'
  end

  
  
  def opensearch
    require 'opensearch_feed'
    if params['type'] and params['type'] != ""
      type = params['type']
    else
      type = 'atom'
    end
    
    if params[:type] == 'json'
      self.json_response
      return
    end
    if params['page'] and params['page'] != ""
      offset = (params['page'].to_i * 25) - 25
    else
      params['page'] = "1"
      offset = 0
    end
    titles = Journal.find_by_contents(params['query'], {:limit=>25, :offset=>offset})
    search_results = []
    if titles
      for title in titles do

      end
    end
    attrs={:search_terms=>params['query'], :total_results=>titles.total_hits.to_s,
      :start_index=>offset.to_s, :count=>"25"}
    feed = FeedTools::OpensearchFeed.new(attrs)
    feed.title = "Search for "+params['query']
    feed.author = "Georgia Tech Library"
    feed.id='http://'+request.host+request.request_uri
    feed.previous_page = url_for(:action=>'opensearch', :query=>params['query'], :page=>(params['page'].to_i - 1).to_s, :type=>type) unless params['page'] == 1
    last = titles.total_hits/25
    feed.next_page=url_for(:action=>'opensearch', :query=>params['query'], :page=>(params['page'].to_i + 1).to_s, :type=>type) unless params['page'] == last.to_s
    feed.last_page=url_for(:action=>'opensearch', :query=>params['query'], :page=>last.to_s, :type=>type)
    feed.href=CGI::escapeHTML('http://'+request.host+request.request_uri)
    feed.search_page=url_for(:action=>'opensearch_description')
    feed.feed_type = params[:type]
    titles.each do |title|
      co = OpenURL::ContextObject.new
      co.referent.set_metadata('jtitle', title.title)
      issn = nil
      if title.issn
        co.referent.set_metadata('issn', title.issn)
        issn = title.issn
      elsif title.eissn
        co.referent.set_metadata('eissn', title.eissn)      
        title.eissn
      end
      co.referent.set_format('journal')
      co.referent.set_metadata('genre', 'journal')
      co.referent.set_metadata('object_id', title.object_id.to_s)
      search_results << co    
      f = FeedTools::FeedItem.new
      
      f.title = co.referent.metadata['jtitle']
      f.title << " ("+issn+")" if issn
      f.link= url_for_with_co({:controller=>'resolve'}, co)
      f.id = f.link
      smry = []
      title.coverages.each do | cvr |
        smry << cvr.provider+':  '+cvr.coverage unless smry.index(cvr.provider+':  '+cvr.coverage)
      end
      f.summary = smry.join('<br />')
      feed << f
    end    
  	@headers["Content-Type"] = "application/"+type+"+xml"
  	render_text feed.build_xml    
            
  end 
  
  def json_response
    if params[:page] and params[:page] != ""
      offset = (params['page'].to_i * 25) - 25
    else
      params[:page] = "1"
      offset = 0
    end
    journals = Journal.find_by_contents(params['query'], {:limit=>25, :offset=>offset})
    
    results={:searchTerms=>params['query'], :totalResults=>journals.total_hits,
      :startIndex=>offset, :itemsPerPage=>"25", :items=>[]}

    results[:title] = "Search for "+params['query']
    results[:author] = "Georgia Tech Library"
    results[:description] = "Georgia Tech Library eJournals"
    results[:id] = 'http://'+request.host+request.request_uri
    results[:previous] = url_for(:action=>'opensearch', :query=>params['query'], :page=>(params[:page].to_i - 1).to_s, :type=>type) unless params[:page] == 1
    last = journals.total_hits/25
    results[:next]=url_for(:action=>'opensearch', :query=>params['query'], :page=>(params[:page].to_i + 1).to_s, :type=>type) unless params[:page] == last.to_s
    results[:last]=url_for(:action=>'opensearch', :query=>params['query'], :page=>last.to_s, :type=>type)
    results[:href]=CGI::escapeHTML('http://'+request.host+request.request_uri)
    results[:search]=url_for(:action=>'opensearch_description')
  
    journals.each {|result|
      issn = ''
      if result.issn
        issn = ' ('+result.issn+')'
      elsif result.eissn
        issn = ' ('+result.eissn+')'      
      end
      item = {:title=>result.title+issn}
      co = OpenURL::ContextObject.new
      co.referent.set_format('journal')
      co.referent.set_metadata('issn', issn) unless issn.blank?
      co.referent.set_metadata('jtitle', result.title)
      item[:link]= url_for_with_co({:controller=>'resolve'}, co)
      item[:id] = item[:link]
      smry = []
      result.coverages.each do | cvr |
        smry << cvr.provider+':  '+cvr.coverage unless smry.index(cvr.provider+':  '+cvr.coverage)
      end
      item[:description] = smry.join('<br />')      
      item[:author] = "Georgia Tech Library"
      results[:items] << item
    }    
  	@headers["Content-Type"] = "text/plain"
  	render_text results.to_json
  end
    
  
  def opensearch_description
    @headers['Content-Type'] = 'application/opensearchdescription+xml' 
  end

  protected

  def normalize_params
    # citation search params  
  
    # sfx.title_search and umlaut.title_search_type are synonyms
    params["sfx.title_search"] = params["umlaut.title_search_type"] if params["sfx.title_search"].blank?
    params["umlaut.title_search_type"] = params["sfx.title_search"] if params["umlaut.title_search_type"].blank?
    
    # Likewise, params[:journal][:title] is legacy params['rft.jtitle']
    unless (params[:journal].blank? || params[:journal][:title].blank? ||
            ! params['rft.jtitle'].blank? )
      params['rft.jtitle'] = params[:journal][:title]
    end

    if ( (params[:journal].blank? || params[:journal][:title].blank?) &&
          params['rft.jtitle'] )
      params[:journal] ||= {}
      params[:journal][:title] = params['rft.jtitle']
    end

    
    # Grab identifiers out of the way we've encoded em
    # Accept legacy SFX-style encodings too
    if ( ! params['rft_id_value'].blank? ||
        ! params['pmid_value'].blank? || 
        ! params['doi_value'].blank?  )

      if (! params['rft_id_value'].blank?)
        id_type = params['rft_id_type'] || 'doi'
        id_value = params['rft_id_value']
      elsif (! params['pmid_value'].blank?)
        id_type = params['pmid_id'] || 'pmid'
        id_value = params['pmid_value']
      else # sfx-style doi
        id_type = params['doi_id'] || 'doi'
        id_value = params['doi_value']
      end
              
      params['rft_id'] = "info:#{id_type}/#{id_value}"
  end

    # SFX v2 A-Z list url format---convert to Umlaut
    if params[:letter_group]
      params[:id] = case params[:letter_group].to_i        
        when 1 then '0-9'
        # 2-27 mean A-Z, convert via ASCII value arithmetic.  
        when 2..27 then ((params[:letter_group].to_i) +63 ).chr
        when 28 then 'Others'
      end
      params.delete(:letter_group) if params[:id]
    end

    # SFX v3 A-Z list url format--convert to Umlaut
    if params[:param_letter_group_value]
      params[:id] = case params[:param_letter_group_value]
        when /^0/ then '0-9'
        when 'Others' then 'Other'
        else params[:param_letter_group_value]
      end          
    end

    # Normalize request for 'Others'
    if params[:id] =~ /^other/i 
       params[:id] = 'Others'
    end

  end

  def context_object_from_params
    params_c = params.clone  

    # Take out the weird ones that aren't really part of the OpenURL
    ignored_keys = [:journal, "__year", "__month", "__day", "action", "controller", "Generate_OpenURL2", "rft_id_type", "rft_id_value"]
    ignored_keys.each { |k| params_c.delete(k) }
    
    # Enhance and normalize metadata a bit, before
    # making a context object
    jrnl = nil
    # Normalize ISSN to have dash
    if ( ! params['rft.issn'].blank? && params['rft.issn'][4,1] != '-' && params['rft.issn'].length >= 4)
      params['rft.issn'].insert(4,'-')
    end

    # Enhance with info from local journal index, if we can
    if ( @use_umlaut_journal_index)
      # Try a few different ways to find a journal object
      jrnl = Journal.find_by_object_id(params_c['rft.object_id']) unless params_c['rft.object_id'].blank?
      jrnl = Journal.find_by_issn(params_c['rft.issn']) unless jrnl || params_c['rft.issn'].blank?
      jrnl = Journal.find(:first, :conditions=>['lower(title) = ?',params_c['rft.jtitle']]) unless (jrnl || params_c['rft.jtitle'].blank?)
 
      if (jrnl && params_c['rft.issn'].blank?)
        params_c['rft.issn'] = jrnl.issn
      end
      if (jrnl && params_c['rft.object_id'].blank? )
        params_c['rft.object_id'] = jrnl[:object_id].to_s
      end
      if (jrnl && params_c['rft.jtitle'].blank?)
        params_c['rft.jtitle'] = jrnl.title
      end
    end
    

    ctx = OpenURL::ContextObject.new
    # Make sure it uses a journal type referent please, that's what we've
    # got here.
    ctx.referent = OpenURL::ContextObjectEntity.new_from_format( 'info:ofi/fmt:xml:xsd:journal' )
    ctx.import_hash( params_c )

    # Not sure where ":rft_id_value" as opposed to 'rft_id' comes from, but
    # it was in old code. We do it after CO creation to handle multiple
    # identifiers
    if (! params_c[:rft_id_value].blank?)
      ctx.referent.add_identifier( params_c[:rft_id_value] )
    end

    return ctx
  end

  def init_context_object_and_resolve
    co = context_object_from_params

    # Add our controller param to the context object, and redirect
    redirect_to url_for_with_co( {:controller=>'resolve'}, co)
  end

  # Talk directly to SFX mysql to find the hits by journal Title.
  # Uses A-Z list "version 3".  
  # Works with SFX 3.0. Will probably break with SFX 4.0, naturally.
  # Returns an Array of ContextObjects. 
  def find_by_title_via_sfx_db    
    search_type = params['umlaut.title_search_type'] || 'contains'
    title_q = params['rft.jtitle']

    object_ids, @hits = object_ids_local_sfx_db(title_q, search_type, @batch_size, @page)
              
    # Now fetch objects with publication information
    sfx_objects = SfxDb::Object.find( object_ids,
    :include => [:publishers, :main_titles, :primary_issns, :primary_isbns])
    
    # We got the right set of @batch_size objects, but they're not sorted
    # by title. 
    # Too hard to include the sort in the SQL, let's re-sort in memory
    sfx_objects.sort! do |a,b| 
      if (a.main_titles.first && b.main_titles.first)
        a.main_titles.first.TITLE_DISPLAY <=> b.main_titles.first.TITLE_DISPLAY
      else
        0
      end
    end
    
    # Now we need to convert to ContextObjects.
    context_objects = sfx_objects.collect do |sfx_obj|
      ctx = OpenURL::ContextObject.new
      # Start out with everything in the search, to preserve date/vol info
      ctx.import_context_object( @search_context_object )

      # Put SFX object id in rft.object_id, that's what SFX does. 
      ctx.referent.set_metadata('object_id', sfx_obj.id.to_s)

      publisher_obj = sfx_obj.publishers.first
      if ( publisher_obj )
        ctx.referent.set_metadata('pub', publisher_obj.PUBLISHER_DISPLAY)
        ctx.referent.set_metadata('place', publisher_obj.PLACE_OF_PUBLICATION_DISPLAY)
      end
      
      title_obj = sfx_obj.main_titles.first
      title = title_obj ? title_obj.TITLE_DISPLAY : "Unknown Title"
      ctx.referent.set_metadata('jtitle', title)

      issn_obj = sfx_obj.primary_issns.first
      ctx.referent.set_metadata('issn', issn_obj.ISSN_ID) if issn_obj

      isbn_obj = sfx_obj.primary_isbns.first     
      ctx.referent.set_metadata('isbn', isbn_obj.ISBN_ID) if isbn_obj
      
      ctx
    end

    @display_results = context_objects 
  end

  # Object Ids from SFX A-Z list.
  # input title query, search_type
  # Returns an array [ batch_obj_id_array, count ].
  # Uses either v2 AZ list or V2 azlist.   
  def object_ids_local_sfx_db(title_q, search_type, batch_size, page)
    ids = nil
  
    begin
      ids = object_ids_az_v3(title_q, search_type, batch_size, page)
    rescue
      # the v3 A-Z list has an annoying habit of being unavailable
      # for 2-3 hours a day, plus it goes down all the time. So if it
      # doesn't work, resort to v2. 
      ids = object_ids_az_v2(title_q, search_type, batch_size, page)      
    end
    return ids
  end

  # Uses the Ex Libris "version 2" AZ list via direct SFX connection.  
  def object_ids_az_v2(title_q, search_type, batch_size, page)
    conditions = case search_type
      when 'contains'
        ['TITLE_DISPLAY like ? OR TITLE_NORMALIZED like ?', "%" + title_q.upcase + "%", "%" + title_q.upcase + "%"]
      when 'begins'
       ['TITLE_DISPLAY like ? OR TITLE_NORMALIZED like ?', title_q + '%', title_q + '%']
      else # exact
        ['TITLE_DISPLAY = ? OR TITLE_NORMALIZED =  ?', title_q, title_q]
    end

    # Get total count
    total_hits = SfxDb::AzTitleV2.count(:OBJECT_ID, 
    :distinct=>true,
    :conditions=>conditions)

    # Now fetch object_ids for just the display batch
    object_ids = SfxDb::AzTitleV2.find(:all, :select=>"distinct (OBJECT_ID)",
    :conditions => conditions, 
    :limit => batch_size,
    :offset => batch_size * (page - 1),
    :order=>'AZ_TITLE_ORDER ASC').collect { |title_obj| title_obj.OBJECT_ID}

    return object_ids, total_hits
  end

  
  # Object Ids from SFX A-Z list 'version 3'. The A-Z v3 title list
  # is cranky, so we have a v2 version too. 
  # input title query, search_type
  # Returns an array [ batch_obj_id_array, count ]. 
  def object_ids_az_v3(title_q, search_type, batch_size, page)
    # MySQL 'like' is case-insensitive, fortunately, don't need to worry
    # about that. But to deal with non-filing chars, need to search against
    # TITLE_DISPLAY and TITLE_SORT for begins with. We're going to join
    # to AZ_TITLE_SEARCH_VER3 for alternate titles too. 
    conditions = case search_type
      when 'contains'
        ['AZ_PROFILE = ? AND TITLE_DISPLAY like ? OR ts.TITLE_SEARCH like ?',
        sfx_az_profile,
        "%" + title_q.upcase + "%", "%" + title_q.upcase + "%"]
      when 'begins'
       ['AZ_PROFILE = ? AND TITLE_DISPLAY like ? OR TITLE_SORT like ? OR ts.TITLE_SEARCH like ?',
       sfx_az_profile,
       title_q + '%', title_q + '%', title_q + "%"]
      else # exact
        ['AZ_PROFILE = ? AND TITLE_DISPLAY = ? OR TITLE_SORT =  ? OR ts.TITLE_SEARCH = ?', 
        sfx_az_profile,
        title_q, title_q, title_q]
    end

    # First get object_ids we're interested in, then
    # we'll bulk fetch with all their data. 
    # Tricky-ass query for efficiency and power, sorry.
    joins = "as ti left outer join AZ_TITLE_SEARCH_VER3 as ts on ti.AZ_TITLE_VER3_ID = ts.AZ_TITLE_VER3_ID"

    
    # Actually, _first_ we'll do a total count.
    total_hits = SfxDb::AzTitle.count(:OBJECT_ID, 
    :distinct=>true,
    :conditions=>conditions,
    :joins=>joins,
    :order=>'TITLE_SORT ASC')

    # Now fetch object_ids for just the display batch
    object_ids = SfxDb::AzTitle.find(:all, :select=>"distinct (OBJECT_ID)",
    :conditions => conditions, 
    :joins => joins,
    :limit => batch_size,
    :offset => batch_size * (page - 1),
    :order=>'TITLE_SORT ASC').collect { |title_obj| title_obj.OBJECT_ID}


    return [ object_ids, total_hits]
  end

  # sfx a-z profile as defined in config, used for direct db connections
  # to sfx. 
  def sfx_az_profile
    AppConfig.param("sfx_az_profile", "default")
  end

  # This guy actually works to talk to an SFX instance over API.
  # But it's really slow. And SFX doesn't seem to take account
  # of year/volume/issue when displaying multiple results anyway!!
  # So it does nothing of value for us--this code may not be working
  # right now. 
  def find_via_remote_title_source(context_object)
      ctx = context_object
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
      return search_results     
  end

 
  # This isn't working right now. It needs to be fixed up quite a bit.
  # Should use the instance variables defined in journal_search,
  # and do a 'count' search, putting results in @hits, putting
  # just the current batch in @display_results. 
  def find_via_local_title_source
    offset = @batch_size * (@page - 1),
    
    unless session[:search] == {:title_search=>params['sfx.title_search'], :title=>params['rft.jtitle']}
      session[:search] = {:title_search=>params['sfx.title_search'], :title=>params['rft.jtitle']}

      titles = case params['sfx.title_search']    
        when 'begins'          
          Journal.find(:all, :conditions=>['lower(title) LIKE ?', params['rft.jtitle'].downcase+"%"], :offset=>offset, :limit=>@batch_size)
        else
          qry = params['rft.jtitle']
          qry = '"'+qry+'"' if qry.match(/\s/)        
          options = {:limit=>@batch_size, :offset=>offset}
          Journal.find_by_contents('alternate_titles:'+qry, options)         
        end
      
      ids = []
      titles.each { | title |
        ids << title.journal_id
      }   
      session[:search_results] = ids.uniq
    end
    @hits = session[:search_results].length
    if params[:page]
      start_idx = (params[:page].to_i*10-10)
    else
      start_idx = 0
    end
    if session[:search_results].length < start_idx + 9
      end_idx = (session[:search_results].length - 1)
    else 
      end_idx = start_idx + 9
    end
    search_results = []
    if session[:search_results].length > 0
      Journal.find(session[:search_results][start_idx..end_idx]).each {| journal |
        co = OpenURL::ContextObject.new
        # import the search criteria, so we can pass em on
        co.import_context_object( @search_context_object )
        
        co.referent.set_metadata('jtitle', journal.title)
        unless journal.issn.blank?
          co.referent.set_metadata('issn', journal.issn)
        end
        co.referent.set_format('journal')
        co.referent.set_metadata('genre', 'journal')
        co.referent.set_metadata('object_id', journal[:object_id].to_s)
        search_results << co
      }
    end
    return search_results
  end


 
end
