require "socket"
require "./temp-email/server.cr"
require "./temp-email/messages.cr"
require "./temp-email/config.cr"
require "./temp-email/db.cr"

module TempEmail
  VERSION = "0.1.0"

  begin
    
    config = Config.new

    db = TempEmailDB.new(config)

    channels = [] of Channel(Msg)

    new_connections = Channel(Msg).new # make the channel on which we receive new connections

    # Fiber that listens for connections
    spawn do
      server = TCPServer.new(12345)
      while client = server.accept?
        new_connections.send(client)
      end
    end

    channels << new_connections

    # main loop; receive new connections and reply to existing ones

    loop do
      index, msg = Channel.select(channels.map(&.receive_select_action))
      # the type of the incoming message is sufficient to determine what it's for
      case
      when msg.is_a?(TCPSocket)
        channel = Channel(Msg).new
        channels << channel
        spawn Server.start(msg, channel)
        STDERR.puts "Started server for new connection from #{msg.inspect}"
      when msg.is_a?(Nil)
        channels.delete_at(index)
        STDERR.puts "Client index #{index} disconnected"
      when msg.is_a?(Data)
        STDERR.puts "Received query \"#{msg}\" from client #{index}"
        channels[index].send(
          if msg[0].is_a?(Symbol)
            case msg[0]
            when :query
              case msg[1].chomp
              when /^get (\S+)$/i
                result = db.check_address($1)
                case result[0]
                when TempEmailDB::FOUND
                  # we know about this address, return it
                  { result[0], result[1].as(String) }
                when TempEmailDB::EXPIRED, TempEmailDB::EXPENDED
                  # we know about it but it has expired or run out of uses
                  { result[0], "unknown" }
                when TempEmailDB::UNKNOWN
                  # here we'd do matching against all the rules and possibly create a new address
                  # but just fail for now
                  { TempEmailDB::UNKNOWN, "unknown" }
                else
                  # we shouldn't get here but currently not type-enforced
                  { TempEmailDB::UNKNOWN, "unknown" }
                end
              else
                { 402, "bad request" }
              end
            else
              # we don't understand this symbol
              { 401, "internal error" }
            end
          else
            { 403, "internal error" }
          end
        )
      else
        STDERR.puts "Unknown request #{msg.inspect} #{msg.class}"
      end
    end

  rescue e : Exception

    if e.is_a?(ArgumentError)
      STDERR.puts "#{PROGRAM_NAME}: #{e.class}: #{e.message}"
    else
      raise e
    end

  end
  
end
