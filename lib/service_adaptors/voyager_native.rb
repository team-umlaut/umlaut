require 'service_adaptors/voyager'
class VoyagerNative < Voyager
  attr_reader :username, :password, :dsn
  def init_holdings_client
    return VoyagerClient.new(self)
  end
end