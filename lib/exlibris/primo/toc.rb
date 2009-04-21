module Exlibris::Primo
  # Class for handling Primo TOCs from links/linktotoc
  # TODO: Should probably extend a base class of some sort
  class Toc
    attr_accessor :record_id
    attr_accessor :url, :display
    attr_accessor :notes, :text
    def initialize(e)
      @text = e.inner_text unless e.nil?
      a = @text.split(/\$(?=\$)/) unless @text.nil?
      a.each do |s|
        @url = s.sub!(/^\$U/, "")  unless s.match(/^\$U/).nil?
        @display = s.sub!(/^\$D/, "")  unless s.match(/^\$D/).nil?
      end
    end
  end
end