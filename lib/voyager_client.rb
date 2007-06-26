class VoyagerClient
  attr_reader :number_of_results, :results
  require 'oci8'	
  def initialize(service)
    @results = []
    begin
      @conn = OCI8.new(service.username, service.password, service.dsn)
  	rescue OCIError
  	end
  end
  
  def get_holdings(bib_nums)		
  	results = {}
    begin 
      query = 'SELECT BIB_ITEM.BIB_ID, BIB_ITEM.ITEM_ID, ITEM_STATUS.ITEM_STATUS, ITEM_STATUS.ITEM_STATUS_DATE, ITEM_STATUS_TYPE.ITEM_STATUS_DESC,	MFHD_MASTER.DISPLAY_CALL_NO, LOCATION.LOCATION_NAME, LOCATION.LOCATION_DISPLAY_NAME, MFHD_ITEM.ITEM_ENUM,	MFHD_ITEM.CHRON, MFHD_ITEM.YEAR FROM BIB_ITEM, MFHD_ITEM, ITEM_STATUS, ITEM_STATUS_TYPE, MFHD_MASTER, LOCATION WHERE BIB_ITEM.BIB_ID IN ('+bib_nums.join(', ')+') AND BIB_ITEM.ITEM_ID=MFHD_ITEM.ITEM_ID AND BIB_ITEM.ITEM_ID=ITEM_STATUS.ITEM_ID AND ITEM_STATUS.ITEM_STATUS = ITEM_STATUS_TYPE.ITEM_STATUS_TYPE AND MFHD_MASTER.MFHD_ID=MFHD_ITEM.MFHD_ID AND MFHD_MASTER.LOCATION_ID=LOCATION.LOCATION_ID'
      cursor = @conn.parse(query)
      cursor.exec

      while row = cursor.fetch()
        new_holding = true
        unless holding = self.search_holdings(row[0])
          holding = Holding.new
          holding.identifier = row[0]
        else
          new_holding = false
        end
        unless location = holding.find_location(row[7])
          location = HoldingLocation.new
          location.name = row[7]
          location.code = row[6]
          holding.locations << location
        end
        item = HoldingItem.new
        item.status_code = row[2]
        item.status_date = row[3]
        item.status = row[4]
        item.call_number = row[5]
        item.enumeration = row[8]
        item.chron = row[9]
        item.year = row[10]
        location.items << item
        @results << holding if new_holding         
      end

      #
      # Do another query to grab current periodicals
      #
      
      query = 'SELECT LINE_ITEM.BIB_ID, SERIAL_ISSUES.ISSUE_ID, LOCATION.LOCATION_NAME, LOCATION.LOCATION_DISPLAY_NAME, SERIAL_ISSUES.LVL1, SERIAL_ISSUES.LVL2, SERIAL_ISSUES.CHRON1 FROM SERIAL_ISSUES, SUBSCRIPTION, LINE_ITEM, COMPONENT, LOCATION, ISSUES_RECEIVED WHERE LINE_ITEM.LINE_ITEM_ID = SUBSCRIPTION.LINE_ITEM_ID AND SUBSCRIPTION.SUBSCRIPTION_ID = COMPONENT.SUBSCRIPTION_ID AND COMPONENT.COMPONENT_ID = SERIAL_ISSUES.COMPONENT_ID AND SERIAL_ISSUES.RECEIVED = 1 AND SERIAL_ISSUES.ISSUE_ID = ISSUES_RECEIVED.ISSUE_ID AND SERIAL_ISSUES.COMPONENT_ID = ISSUES_RECEIVED.COMPONENT_ID AND ISSUES_RECEIVED.LOCATION_ID = LOCATION.LOCATION_ID AND LINE_ITEM.BIB_ID IN ('+bib_nums.join(', ')+')'
      cursor = @conn.parse(query)
      cursor.exec
      while row = cursor.fetch()
        new_holding = true
        unless holding = self.search_holdings(row[0])
          holding = Holding.new
          holding.identifier = row[0]
          call_no = nil
        else
          new_holding = false
          call_no = holding.locations[0].items[0].call_number
        end     
        enum = ''
        if row[4]
          enum += 'VOL '+row[4].to_s
        end
        if row[5]
          enum += ' NO '+row[5].to_s
        end
        unless enum.blank?  
          next if holding.find_item_by_attribute('enumeration', enum)         
        end
        unless location = holding.find_location(row[3])
          location = HoldingLocation.new
          location.name = row[3]
          location.code = row[2]
          holding.locations << location
        end 
        item = HoldingItem.new
        item.status_code = 1
        item.status_date = ""
        item.status = 'Available'
        item.call_number = call_no
        item.enumeration = enum
        item.chron = row[6]
        item.year = row[6]
        location.items << item
        @results << holding if new_holding                               	
      end	
      @conn.logoff
  	rescue OCIError      
  	end
  end
  
  def search_holdings(bib_id)
    @results.each do | holding |
      return holding if holding.identifier == bib_id
    end
    return nil
  end
end