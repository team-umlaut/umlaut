# A very simple service that simply generates a "highlighted_link" to
# the Ulrich's periodical directory, if an ISSN is present.
# Does not actually look up first to make sure there are results, it's
# a blind link.
# config params:
# link_name: Name to put on the link. Defaults to "Periodical Information from Ulrich's Directory". 
class UlrichsLink < Service

  def initialize(config)
    # Original one, which just apes the UlrichsWeb html interface, and gives
    # you a search results screen even with only one hit. 
    #@base_url = "http://www.ulrichsweb.com/ulrichsweb/Search/doAdvancedSearch.asp?QuickCriteria=ISSN&Action=Search&collection=SERIAL&QueryMode=Simple&ResultTemplate=quickSearchResults.hts&SortOrder=Asc&SortField=f_display_title&ScoreThreshold=0&ResultCount=25&SrchFrm=Home&setting_saving=on&QuickCriteriaText="
    super(config)
    # better one, which Yvette at Ulrich's showed me for SFX, which seems to work better.
    @vendor ||= "Umlaut"
    @base_url ||= "https://ulrichsweb.serialssolutions.com/api/openurl?issn="
    # Old one
    #@base_url ||= "http://www.ulrichsweb.com/ulrichsweb/Search/call_fullCitation.asp?/vendor_redirect.asp?oVendor=#{@vendor}&oIssn="
    @link_name = "Periodical information"
  end
  
  def service_types_generated
    return [ServiceTypeValue[:highlighted_link]]
  end

  def handle(request)
    unless (request.referent.issn.blank?)
      display_text = @link_name

      url = url_for_issn( request.referent.issn )
      
      request.add_service_response(
        :service=>self, 
        :url=>url, 
        :display_text=>display_text,
        :service_type_value => :highlighted_link)
    end

    return request.dispatched(self, true)
  end

  def url_for_issn(issn)
    # with or without hyphen should work fine. 
    return @base_url + issn
  end
  
end
