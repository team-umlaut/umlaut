require 'cgi'
require 'openurl'

# Just creates an OpenURL link out, corresponding to the current OpenURL. 
# But tweaked in ways to try and work out for sending to ILLiad. 
#
# If you use SFX, you may want to just use SFX's built-in ILLiad targets, which
# will generally be picked up by the SFX Umlaut service. 
#
# But if you don't or if you are unhappy with what SFX is doing, you could turn
# off ILLiad target(s) in SFX (or configure Umlaut SFX adapter to ignore them), 
# and use this instead. 
#
# # Pre-empting
#
# You may want to show ILLiad links only if there is no fulltext, or only if there
# is no fulltext from a certain service. You can use Umlaut's standard service
# pre-emption configuration for that. 
#
# Do not produce ILLiad links if there are ANY fulltext links already produced
# in the request. In umlaut_services.yml:
#
#     illiad:
#       type: Illiad
#       base_url: http://ill.university.edu/site/illiad.dll/OpenURL
#       priority: 4
#       preempted_by:
#         existing_type: fulltext
#
# Or, preempt ILLiad links only if there are fulltext links created by SFX
# specifically (assume "SFX" is the id of your sfx service in umlaut_services.yml)
#
#     illiad:
#       type: Illiad
#       base_url: http://ill.university.edu/site/illiad.dll/OpenURL
#       priority: 4
#       preempted_by:
#         existing_service: SFX
#         existing_type: fulltext
#
# Pre-emption can only take account of services already generated before ILLiad
# service is triggered, so you'd want to make sure to give ILLiad a priority greater
# than the services you want to potentially preempt it. 
#
# # Config parameters
# ## Required
# 
# * base_url: Illiad base url, such as `http://ill.university.edu/site/illiad.dll/OpenURL`. It should probably end in '/illiad.dll/OpenURL'
#
# ## Optional
# 
# * display_name: Default "Place ILL Request"
# * sid_suffix: Default " (via Umlaut)", appended to existing sid before sending to ILLiad. 
# * notes: Some additional notes to display under the link. 
class Illiad < Service
  include MetadataHelper

  required_config_params :base_url

  def initialize(config)
    @service_type = "document_delivery"
    @display_name = "Place ILL Request"
    @sid_suffix   = " (via Umlaut)"

    super(config)    
  end


  def service_types_generated
    [ServiceTypeValue[@service_type.to_sym]]
  end

  def handle(request)   
    target_url = @base_url + "?" + illiad_query_parameters(request).to_query

    request.add_service_response(
      :service            =>self, 
      :display_text       => @display_name,
      :url                => target_url,
      :notes              => @notes, 
      :service_type_value => @service_type.to_sym
    )

    return request.dispatched(self, true)
  end

  
  def illiad_query_parameters(request)
    metadata = request.referent.metadata

    qp = {}

    qp['genre']     = metadata['genre']

    if metadata['aulast']
      qp["aulast"]  = metadata['aulast']
      qp["aufirst"] = [metadata['aufirst'], metadata["auinit"]].find {|a| a.present?}
    else
      qp["au"]      = metadata["au"]
    end

    qp['volume']    = metadata['volume']
    qp['issue']     = metadata['issue']

    qp['spage']     = get_spage(request.referent)
    qp['epage']     = get_epage(request.referent)

    qp['issn']      = get_issn(request.referent)
    qp['isbn']      = get_isbn(request.referent)
    qp['pmid']      = get_pmid(request.referent)

    qp['stitle']    = metadata['stitle']

    qp['sid']       = sid_for_illiad(request)

    qp['year']      = get_year(request.referent)
    qp['month']     = get_month(request.referent)

    qp['atitle']    = metadata['atitle']

    # ILLiad always wants 'title', not the various title keys that exist in OpenURL
    qp['title']     = [metadata['jtitle'], metadata['btitle'], metadata['title']].find {|a| a.present?}

    # For some reason these go to ILLiad prefixed with rft.
    qp['rft.pub']     = metadata['pub']
    qp['rft.place']   = metadata['place']
    qp['rft.edition'] = metadata['edition']

    # ILLiad likes OCLCnum in `rfe_dat`
    qp['rfe_dat']   = get_oclcnum(request.referent)


    # Genre normalization. ILLiad pays a lot of attention to `&genre`, but
    # doesn't use actual OpenURL rft_val_fmt
    if request.referent.format == "dissertation"
      qp['genre'] = 'dissertation'
    elsif qp['isbn'].present? && qp['genre'] == 'book' && qp['atitle'] && (! qp['issn'].present?)
      # actually a book chapter, not a book, fix it. 
      qp['genre'] = 'bookitem'
    elsif qp['issn'].present? && qp['atitle'].present?
      # Otherwise, if there is an ISSN, we force genre to 'article', seems
      # to work best.  
      qp['genre'] = 'article'      
    elsif qp['genre'] == 'unknown' && qp['atitle'].blank?
      # WorldCat likes to send these, ILLiad is happier considering them 'book'
      qp['genre'] = "book"
    end

    # trim empty ones please
    qp.delete_if {|k, v| v.blank?}
    
    return qp
  end

  # Grab a source label out of `sid` or `rfr_id`, add on our suffix. 
  def sid_for_illiad(request)    
    sid = request.referrer_id || ""

    sid = sid.gsub(%r{\Ainfo\:sid/}, '')

    return "#{sid}#{@sid_suffix}"
  end
end