# The search controller handles searches fo manually entered citations,
# or possibly ambiguous citations generally. It also provides an A-Z list.
#
# As a source of this data, it generally talks to the SFX database directly.
# The particular method it uses to get this data is defined in a SearchMethod
# module (app/controllers/search_methods), that gets applied to the controller.
# Currently Sfx4 direct database and Sfx4Solr (SFX indexed in Solr via Sunspot)
# are supported.
# In either case with database connection info in your database.yml file under
# sfx_db.
#
# Future plans include a local database of titles, perhaps loaded from an
# external KB. Not done yet.
#
# = SearchMethod module implementation
# A search method is just a ruby module, that will be applied to a controller,
# that defines two methods:
#   [#find_by_title]
#     Takes no arguments, instead use methods in the controller like
#     #sfx_az_profile, #title_query_param, #search_type_param, #batch_size and
#     #page to return state.  Returns a two-element array pair, first element
#     is a list of OpenURL::ContextObject for current batch, send element
#     is int total hit count.
#   [#find_by_group]
#     Used for clicks on "A", "B" ... "0-9", "Other" links.  Find the group
#     link clicked on in params[:id].  Use #batch_size and #page for paging.
#     As in #find_by_title, return two element array, first elememt is array
#     of OpenURL::ContextObject, second element is total hit count.
class SearchController < UmlautController
  @@search_batch_size = 20
  @@az_batch_size = 20
  @@autocomplete_limit = 15

  layout :layout_name, :except => [ :opensearch, :opensearch_description ]

  before_filter :normalize_params

  def initialize(*params)
    super(*params)
    self.extend( search_method_module )
  end

  def index
    @page_title = t('umlaut.search.journals_page_name')
    journals()
  end

  def journals
    @submit_hash = params["umlaut.display_coins"] ? {:controller=>'resolve', :action=>'display_coins'} : {:controller=>'search', :action=>'journal_search'}

    # Render configed view, if configed, or default
    render umlaut_config.lookup!("search_view", "journals")
  end

  # Not sure if this action actually works or does anything at present.
  def books
     @submit_action = params["umlaut.display_coins"] ? "display_coins" : "index"
  end

  # @display_results is left as an array of ContextObject objects.
  # Or, redirect to resolve action for single hit.
  # O hit also redirects to resolve action, as per SFX behavior--this
  # gives a catalog lookup and an ILL form for 0-hit.
  # param umlaut.title_search_type (aka sfx.title_search)
  # can be 'begins', 'exact', or 'contains'. Other
  # form params should be OpenURL, generally
  def journal_search
    @batch_size = batch_size
    @start_result_num = (page * batch_size) - (batch_size - 1)
    @search_context_object = context_object_from_params
    if (! params["rft.object_id"].blank? ||
        ! params["rft.issn"].blank? ||
        ! params["rft_id"].blank? )
      # If we have an exact-type 'search', just switch to 'resolve' action
      redirect_to url_for_with_co( {:controller => 'resolve'}, context_object_from_params )
      # don't do anything else.
      return
    elsif (params['rft.jtitle'].blank?)
      #Bad, error condition. If we don't have any of that other stuff above,
      # we need a title!  Send them back to entry page with an error message.
      flash[:error] = "You must enter a journal title or other identifying information."
      redirect_to :controller=>:search, :action=>:index
      return
    end

    # Call our particular search method, #find_by_title added by search
    # method module.
    (@display_results, @hits) = self.find_by_title
    #find_by_title_via_sfx_db

    # Calculate end-result number for display
    @end_result_num = @start_result_num + batch_size - 1
    if @end_result_num > @hits
      @end_result_num = @hits
    end

    if (@page == 1) && (@display_results.length == 1)
      # If we narrowed down to one result redirect
      # to resolve action.
      redirect_to( url_for_with_co({:controller => 'resolve'}, @display_results[0]) )
    elsif (@display_results.length == 0)
      # 0 hits, do it too.
      redirect_to(  url_for_with_co({:controller => 'resolve'}, @search_context_object) )
    end
    @page_title = 'Journal titles that '
    @page_title +=
      (params["umlaut.title_search_type"] == "begins") ?
        'begin with ' : 'contain '
    @page_title += "'" + params['rft.jtitle'] + "'"
  end

  # Used for browse-by-letter
  def journal_list
    @batch_size = batch_size
    @page = page
    @start_result_num = (@page * @batch_size) - (@batch_size - 1)
    (@display_results, @hits) = find_by_group
    # Calculate end-result number for display
    @end_result_num = @start_result_num + @batch_size - 1
    if @end_result_num > @hits
      @end_result_num = @hits
    end
    @page_title = t('umlaut.search.browse_by_jtitle', :query => params['id'])
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
   search_type = params["umlaut.title_search_type"] || "contains"
   unless ( query.blank? )
      (context_objects, total_count) = find_by_title
      @titles = context_objects.collect do |co|
        metadata = co.referent.metadata
        {:object_id => metadata["object_id"], :title => (metadata["jtitle"] || metadata["btitle"] || metadata["title"])}
      end
   end
   render :text => @titles.to_json, :content_type => "application/json"
  end

  def opensearch_description
    @headers['Content-Type'] = 'application/opensearchdescription+xml'
  end

  protected

  # We intentionally use a method calculated at request-time for layout,
  # so it can be changed in config at request-time.
  def layout_name
    umlaut_config.search_layout
  end

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

    # for reasons I can't tell, our JS on IE ends up putting some
    # newlines in the object_id, which messes us all up.
    params['rft.object_id'].strip! if params['rft.object_id']

    ## If needed combine date elements to an OpenURL date
    unless (params["__year"].blank? &&
            params["__month"].blank? &&
            params["__day"].blank?)
      isoDate = ""
      unless ["", "****", "Year"].include?(params["__year"])
        isoDate += params["__year"]
        unless ["", "***", "Month"].include?(params["__month"])
          isoDate += "-" + params["__month"]
          unless ["", "**", "Day"].include?(params["__day"])
            isoDate += "-" + params["__day"]
          end
        end
      end
      unless isoDate.blank?
        params["date"] = isoDate
      end
    end
  end

  def context_object_from_params
    @context_object_from_params ||=
      begin
      params_c = params.clone

      # Take out the weird ones that aren't really part of the OpenURL
      ignored_keys = [:journal, "utf8", "__year", "__month", "__day", "action", "controller", "Generate_OpenURL2", "rft_id_type", "rft_id_value"]
      ignored_keys.each { |k| params_c.delete(k) }

      # Normalize ISSN to have dash
      if ( ! params['rft.issn'].blank? && params['rft.issn'][4,1] != '-' && params['rft.issn'].length >= 4)
        params['rft.issn'].insert(4,'-')
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
      ctx
    end
  end

  def search_method_module
    umlaut_config.lookup!("search.az_search_method", SearchMethods::Sfx4)
  end

  # sfx a-z profile as defined in config, used for direct db connections
  # to sfx.
  def sfx_az_profile
    umlaut_config.lookup!("search.sfx_az_profile", "default")
  end
  helper_method :sfx_az_profile

  def title_query_param
    params['rft.jtitle']
  end
  helper_method :title_query_param

  def search_type_param
    params['umlaut.title_search_type'] || 'contains'
  end
  helper_method :search_type_param

  def batch_size
    case params[:action]
      when "journal_list"
        @@az_batch_size
      when "auto_complete_for_journal_title"
        @@autocomplete_limit
      else
        @@search_batch_size
    end
  end
  helper_method :batch_size

  def page
    @page ||= params['page'].blank? ? 1 : params['page'].to_i
  end
  helper_method :page
end