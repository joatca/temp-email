require "./messages.cr"

module TempEmail

  class Server

    def self.start(client : TCPSocket, ch : Channel(Msg))
      STDERR.puts "#{client.remote_address.address} server started"
      begin
        while query = client.gets
          puts "#{client.remote_address.address} received query #{query}"
          ch.send(Data.new(:query, query))
          response = ch.receive
          puts "received response #{response} for client #{client.remote_address.address}"
          if response.is_a?(Response)
            client.puts "#{response.code} #{response.message}"
          else
            client.puts "400 internal error"
          end
        end
        STDERR.puts "#{client.remote_address.address} exited"
        ch.send(nil)
        ch.close
        client.close
      rescue e : IO::Error
        STDERR.puts "IO error: #{e.message}"
      end
    end

  end

end
