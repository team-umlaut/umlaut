module EmailerHelper
  include ApplicationHelper
  include Umlaut::Helper


  # returns a plain text short citation
  def brief_citation(request, options = {})
    options[:include_labels] ||= false
    rv =""
    cite = request.referent.to_citation
    title = truncate(cite[:title].strip, :length => 70,  :separator => ' ')

    rv << (cite[:title_label].strip + ": ")if options[:include_labels] && cite[:title_label]
    rv << title
    rv << "\n"
    if cite[:author]
      rv << "Author: " if options[:include_labels]
      rv << cite[:author].strip
      rv << "\n"
    end
    if cite[:subtitle]
      rv << (cite[:subtitle_label].strip + ": ") if options[:include_labels] && cite[:subtitle_label]
      rv << cite[:subtitle].strip
      rv << "\n"
    end
    pub = []
    pub << date_format(cite[:date]) unless cite[:date].blank?
    pub << 'Vol: '+cite[:volume].strip unless cite[:volume].blank?
    pub << 'Iss: '+cite[:issue].strip unless cite[:issue].blank?
    pub << 'p. '+cite[:page].strip unless cite[:page].blank?
    if pub.length > 0
      rv << "Published: " if options[:include_labels]
      rv << pub.join('  ')
    end
    return rv
  end

  def citation_identifiers(request, options = {})
    citation = request.referent.to_citation
    str = ""

    str << "ISSN: #{citation[:issn]}\n" if citation[:issn]
    str << "ISBN: #{citation[:isbn]}\n" if citation[:isbn]
    citation[:identifiers].each do |identifier|
      str << "#{identifier}\n"
    end

    return str
  end
end