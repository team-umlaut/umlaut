module Exlibris::Primo::Source
  #require 'exlibris/primo'
  class Base < Exlibris::Primo::Holding
    attr_accessor :source_base_url, :source_type
    attr_reader :source_url

    def initialize(config, e=nil)
      @source_base_url = config["base_url"] unless config.nil?
      @source_type = config["type"] unless config.nil?
      super(e)
    end
    
    def source_url
      source_base_url
    end
  end
end