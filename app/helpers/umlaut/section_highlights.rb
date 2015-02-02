module Umlaut
  # NOT Rails helper methods, but a helper class with logic to determine
  # whether a given umlaut display section should be given the
  # umlaut-section-highlighted class, used to mark recommended access
  # methods. (For instance, fulltext if it's available, or maybe
  # document_delivery if it's not, but it gets more complicated.)
  class SectionHighlights
    attr_reader :umlaut_request, :umlaut_config

    # * First arg is the umlaut Request
    # * Second optional is an UmlautConfiguration object, used for 
    #   `section_highlights_filter` lambda -- will default to
    #   UmlautController.umlaut_config
    def initialize(umlaut_request, umlaut_config = UmlautController.umlaut_config)
      @umlaut_config  = umlaut_config
      @umlaut_request = umlaut_request
    end

    def should_highlight_section?(section_id)
      highlighted_sections.include? section_id.to_s
    end

    # array of section div_id's that should be highlighted for
    # the current request in it's current state. Calculated
    # with calc_highlighted_sections!, then cached. 
    def highlighted_sections
      @highlighted_sections ||= calc_highlighted_sections!
    end

    # Returns an array of zero or more sections to display with 
    # .umlaut-section-highlighted -- usually the recommended section,
    # fulltext if we have it, etc. 
    #
    # A bit hard to get exactly right for both technical and contextual
    # policy issues, this is a basic starting point. 
    def calc_highlighted_sections!
      sections = []

      if umlaut_request.get_service_type("fulltext").present?
        sections << "fulltext"
      end

      # Highlight holdings if it's present AND:
      #   no fulltext is present OR it's a book (non-serial) type
      # We think people want print for books more often. 
      if umlaut_request.get_service_type("holding").present? &&
         ( umlaut_request.get_service_type("fulltext").blank? ||  (! MetadataHelper.title_is_serial?(umlaut_request.referent)) )
        sections << "holding"
      end


      # Return document_delivery as highlighted only if 
      # fulltext and holdings are done being fetched. AND. 
      # If there's no fulltext or holdings, OR there's holdings, but
      # it's a journal type thing, where we probably don't know if the
      # particular volume/issue wanted is present. Ugh. 
      if ( umlaut_request.get_service_type("document_delivery").present? &&
           umlaut_request.get_service_type("fulltext").empty? && 
            (! umlaut_request.service_types_in_progress?(["fulltext", "holding"])) && (
              umlaut_request.get_service_type("holding").empty? || 
              umlaut_request.referent.format == "journal"
            )
          )
        sections << "document_delivery"
      end

      sections = apply_filters!(sections)

      return sections
    end


    def apply_filters!(sections)
      sections = sections.dup

      (umlaut_config.section_highlights_filter || []).each do |filter|
        # filters are expected to mutate 'sections' if they want
        filter.call(umlaut_request, sections, self)
      end

      return sections
    end

  end
end