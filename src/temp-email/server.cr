require "./messages.cr"

module TempEmail

  class Server

    def self.start(client : TCPSocket, ch : Channel(Msg))
      begin
        while query = client.gets
          ch.send(Data.new(:query, query))
          response = ch.receive
          if response.is_a?(Response)
            client.puts "#{response.code} #{response.message}"
          else
            client.puts "400 internal error"
          end
        end
        ch.send(nil)
        ch.close
        client.close
      rescue e : IO::Error
        STDERR.puts "IO error: #{e.message}"
      end
    end

  end

end
