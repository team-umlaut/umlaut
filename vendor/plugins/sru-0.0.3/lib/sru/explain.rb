require 'sru/response'

module SRU
  class ExplainResponse < Response

    def to_s
      return "host=#{host} port=#{port} database=#{database} version=#{version}"
    end

    def host
      return xpath('.//serverInfo/host')
    end

    def port
      port = xpath('.//serverInfo/port')
      return nil if not port
      return Integer(port)
    end

    def database
      return xpath('.//serverInfo/database')
    end
    
    def number_of_records
      return xpath('.//configInfo/numberOfRecords')
    end

    def version
      version = xpath('.//zs:explainResponse/zs:version')
      return version if version

      # also look here 
      info = xpath_first('.//serverInfo')
      return info.attributes['version'] if info
      
      return nil
    end
  end
end
