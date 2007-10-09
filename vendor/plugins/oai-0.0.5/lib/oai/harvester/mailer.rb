module OAI
  module Harvester
    
    class Mailer
    
      def self.send(server = nil, email = nil, message = nil)
        msg = %{Subject: Harvester Summary\n\n#{message.join("\n")}}
        to = (email.map { |e| "'#{e}'"}).join(", ")
        Net::SMTP.start(server) do |smtp|
          smtp.send_message msg, "harvester@#{Socket.gethostname}", to
        end
      end
    
    end
    
  end
end        
