require "./messages.cr"

module TempEmail

  class Server

    def self.start(client : TCPSocket, ch : Channel(Msg))
      STDERR.puts "#{client.remote_address.address} server started"
      begin
        while query = client.gets
          puts "#{client.remote_address.address} received query #{query}"
          ch.send({ :query, query })
          response = ch.receive
          if response.is_a?(Data) && response[0].is_a?(Int32)
            client.puts "#{response[0]} #{response[1]}"
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
