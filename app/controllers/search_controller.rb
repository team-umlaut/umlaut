class SearchController < ApplicationController
  layout "layouts/search_standard", :except => [ :opensearch, :opensearch_description ]
  require 'open_url'
  def index
    self.journals
  	render :action=>'journals'    
  end  
  
  def journals
  
  end
  
  def journal_search    
    if params["sfx.title_search"] == 'exact' or params["rft.object_id"] or params["rft.issn"] or params[:rft_id_value]
      self.init_context_object_and_resolve
    else
      if params['rft.date'] and params['rft.volume'] and params['rft.issue']
        @search_results = self.find_via_remote_title_source
      else
        @search_results = self.find_via_local_title_source
      end
  

      if @search_results.length == 1
        redirect_to @search_results[0].to_hash.merge!(:controller=>'resolve')
      end
    end        
  end

  def journal_list
    require 'journals/sfx_journal'
    @journals = Journal.find_all_by_page(params[:id].downcase, :order=>'normalized_title')

  end  
  
  def init_context_object_and_resolve
    require RAILS_ROOT+'/vendor/open_url'
    ctx = OpenURL::ContextObject.new  
    jrnl = nil
    if params["rft.object_id"]
      jrnl = Journal.find_by_object_id(params["rft.object_id"])
      ctx.referent.set_metadata('object_id', params["rft.object_id"])
    end

    if params[:journal]   
      if params[:journal][:title]
        ctx.referent.set_metadata('jtitle', params[:journal][:title])
      end
    end
    if params["rft.jtitle"] and params["rft.jtitle"] != ""
      ctx.referent.set_metadata('jtitle', params["rft.jtitle"])
    end
    if params["rft.issn"] and params["rft.issn"] != ""
      issn = params["rft.issn"]
     	unless issn[4,1] == "-"
     	  issn.insert(4, '-')
     	end
     	ctx.referent.set_metadata('issn', issn)
    elsif jrnl and jrnl.issn
      ctx.referent.set_metadata('issn', jrnl.issn)
    end
    if ctx.referent.metadata['issn'] or ctx.referent.metadata['jtitle']
      unless jrnl
        if ctx.referent.metadata['issn']
          jrnl = Journal.find_by_issn(ctx.referent.metadata['issn'])
          ctx.referent.set_metadata('object_id', jrnl[:object_id]) if jrnl
          ctx.referent.set_metadata('jtitle', jrnl.title) if jrnl
        else
          jrnl = Journal.find(:first, :conditions=>['lower(title) = ?',ctx.referent.metadata['jtitle']])
          if jrnl
            ctx.referent.set_metadata('object_id', jrnl[:object_id])
            ctx.referent.set_metadata('issn', jrnl.issn) if jrnl.issn
          end
        end
      end
    end
    ctx.referent.set_metadata('date', params['rft.date']) if params['rft.date']
    ctx.referent.set_metadata('volume', params['rft.volume']) if params['rft.volume']
    ctx.referent.set_metadata('volume', params['rft.issue']) if params['rft.issue']

    if params[:rft_id_value] and params[:rft_id_value] != ""
      id = params[:rft_id_value]
      rft_id = case params[:rft_id_type]
                when 'doi' then 'info:doi/'
                else 'info:pmid/'
                end
      rft_id += id.sub(/^(doi:)|(info:doi\/)|(pmid:)|(info:pmid\/)/, '')
      ctx.referent.set_identifier(rft_id)
    end      
    redirect_to ctx.to_hash.merge!(:controller=>'resolve')
  end
  auto_complete_for :journal_title, :titles, :limit=>10
  
  def auto_complete_for_journal_title
    @titles = Journal.find_by_contents("alternate_titles:*"+params[:journal][:title]+"*")
    render :partial => 'journal_titles'  
  end
  
  def find_via_remote_title_source
      inst = Institution.find_by_default_institution('true')
      resolver = inst.link_resolvers[0]
      require 'dispatch_services/link_resolver_clients/sfx_client'
      search_results = []
      ctx = OpenURL::ContextObject.new
      ctx.referent.set_metadata('jtitle', params[:journal][:title])
      if params['rft.date']
        ctx.referent.set_metadata('date', params['rft.date'])
      end
      if params['rft.volume']
        ctx.referent.set_metadata('volume', params['rft.volume'])
      end
      if params['rft.issue']
        ctx.referent.set_metadata('volume', params['rft.issue'])
      end      
      transport = OpenURL::Transport.new(resolver.url, ctx)
      transport.extra_args["sfx.title_search"] = params["sfx.title_search"]
      transport.extra_args["sfx.response_type"] = 'multi_obj_xml'
      transport.transport_inline
      doc = REXML::Document.new transport.response
      client = SfxClient.new(ctx, resolver)
      doc.elements.each('ctx_obj_set/ctx_obj') { | ctx_obj | 
        ctx_attr = ctx_obj.elements['ctx_obj_attributes']
        extended_data = nil
        next unless ctx_attr and ctx_attr.has_text?
        perl_data = REXML::Document.new ctx_attr.get_text.value
        extended_data = client.parse_perl_data(perl_data)
        next if extended_data[:metadata].empty?
        co = OpenURL::ContextObject.new
        fmt_node = REXML::XPath.first(perl_data, "/perldata/hash/item[@key='rft.object_type']")
        if fmt_node
          co.referent.set_format(fmt_node.get_text.value.downcase)
        else 
          co.referent.set_format('journal')        
        end
        client.enhance_context_object(co, extended_data[:metadata])  
        search_results << co
      } 
      return search_results     
  end
  
  def find_via_local_title_source
    offset = 0
    offset = ((params[:page].to_i * 10)-10) if params['page']

    unless session[:search] == {:title_search=>params['sfx.title_search'], :title=>params[:journal][:title]}
      session[:search] = {:title_search=>params['sfx.title_search'], :title=>params[:journal][:title]}

      titles = case params['sfx.title_search']    
        when 'begins'          
          Journal.find(:all, :conditions=>['lower(title) LIKE ?', params[:journal][:title].downcase+"%"], :offset=>offset)
        else
          qry = params[:journal][:title]
          qry = '"'+qry+'"' if qry.match(/\s/)        
          options = {:limit=>:all, :offset=>offset}
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
        co.referent.set_metadata('jtitle', journal.title)
        unless journal.issn.blank?
          co.referent.set_metadata('issn', journal.issn)
        end
        co.referent.set_format('journal')
        co.referent.set_metadata('genre', 'journal')
        co.referent.set_metadata('object_id', journal[:object_id])
        search_results << co
      }
    end
    return search_results
  end

  def rescue_action_in_public(exception)
    if @action_name == 'journal_list'
      render :template => "error/journal_list_error" 
    else
      render :template => "error/search_error"
    end
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
      co.referent.set_metadata('object_id', title.object_id)
      search_results << co    
      f = FeedTools::FeedItem.new
      
      f.title = co.referent.metadata['jtitle']
      f.title << " ("+issn+")" if issn
      f.link= url_for co.to_hash.merge({:controller=>'resolve'})
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
      item[:link]= url_for(co.to_hash.merge({:controller=>'resolve'}))
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
 
end
