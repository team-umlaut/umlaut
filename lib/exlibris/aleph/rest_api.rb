module Exlibris::Aleph
  require 'httparty'
  class RestAPI
    include HTTParty
    format :xml
    def initialize(uri)
      @uri = uri
      raise "Initialization error in #{self.class}. Missing URI." if @uri.nil?
    end
    def error
      return nil if reply_code == "0000" 
      return "#{reply_text}"
    end
    def reply_code
      return "No response." if @response.nil?
      return (not @response.first.last.kind_of?(Hash) or @response.first.last["reply_code"].nil?) ? "Unexpected response hash." : @response.first.last["reply_code"] if @response.instance_of?(Hash)
      response_match = @response.match(/\<reply-code\>(.+)\<\/reply-code\>/) if @response.instance_of?(String)
      return (response_match.nil?) ? "Unexpected response string." : response_match[1] if @response.instance_of?(String)
      return "Unexpected response type."
    end
    def reply_text
      return "No response." if @response.nil?
      return (not @response.first.last.kind_of?(Hash) or @response.first.last["reply_text"].nil?) ? "Unexpected response hash." : @response.first.last["reply_text"] if @response.instance_of?(Hash)
      response_match = @response.match(/\<reply-text\>(.+)\<\/reply-text\>/) if @response.instance_of?(String)
      return (response_match.nil?) ? "Unexpected response string." : response_match[1] if @response.instance_of?(String)
      return "Unexpected response type."
    end
  end
end