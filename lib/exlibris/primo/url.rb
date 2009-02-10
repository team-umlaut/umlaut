module Exlibris::Primo
  # Class for handling Primo URLs from links/linktorsrc
  # TODO: Should probably extend a base class of some sort
  class Url
    attr_accessor :record_id
    attr_accessor :institution, :url, :display, :origin
    attr_accessor :notes, :text
    def initialize(e)
      @text = e.text unless e.nil?
      a = @text.split(/\$(?=\$)/) unless @text.nil?
      a.each do |s|
        v = s.sub!(/^\$V/, "")  unless s.match(/^\$V/).nil?
        @url = s.sub!(/^\$U/, "")  unless s.match(/^\$U/).nil?
        @display = s.sub!(/^\$D/, "")  unless s.match(/^\$D/).nil?
        @institution = s.sub!(/^\$I/, "") unless s.match(/^\$I/).nil?
        @origin = s.sub!(/^\$O/, "") unless s.match(/^\$O/).nil?
      end
    end
  end
end