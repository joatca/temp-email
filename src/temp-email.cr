require "socket"
require "./temp-email/server.cr"
require "./temp-email/messages.cr"
require "./temp-email/config.cr"
require "./temp-email/db.cr"
require "./temp-email/logger.cr"

module TempEmail
  VERSION = "0.1.0"

  begin
    
    config = Config.new

    db = TempEmailDB.new(config)

    log = Channel(String).new(10) # give it a wee buffer
    spawn Logger.start(log)

    log.send("started")
    
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
      when msg.is_a?(Nil)
        channels.delete_at(index)
      when msg.is_a?(Data)
        channels[index].send(
          case msg.verb
          when :query
            case msg.value.chomp
            when /^get (\S+)$/i
              address = $1.as(String)
              db_result = db.check_address(address)
              case db_result[0]
              when TempEmailDB::FOUND
                # we know about this address, return it
                log.send("(#{db_result[2]}) #{address}: #{db_result[1]}")
                Response.new(db_result[0], db_result[1].as(String))
              when TempEmailDB::EXPIRED, TempEmailDB::EXPENDED
                # we know about it but it has expired or run out of uses
                log.send("(#{db_result[2]}) #{address}")
                Response.new(TempEmailDB::UNKNOWN, "unknown")
              when TempEmailDB::UNKNOWN
                # match against all the rules and possibly create a new address
                # we need to figure out a way to evaluate to the string returned if one is, otherwise nil
                match : String?
                match = nil
                config.matchers.each do |m|
                  match = m.check_match(address, db)
                  unless match.nil?
                    break
                  end
                end
                if match.nil?
                  log.send("(no match) #{address}") # should we even log this?
                  Response.new(TempEmailDB::UNKNOWN, "unknown")
                else
                  log.send("(new) #{address}: #{match}")
                  Response.new(TempEmailDB::FOUND, match.as(String))
                end
              else
                # we shouldn't get here but currently not type-enforced
                Response.new(TempEmailDB::UNKNOWN, "unknown")
              end
            else
              Response.new(TempEmailDB::ERROR, "bad request")
            end
          else
            # we don't understand this symbol
            Response.new(TempEmailDB::ERROR, "internal error")
          end
        )
      else
        log.send "Unknown request #{msg.inspect} #{msg.class}"
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
