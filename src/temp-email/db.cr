require "sqlite3"

module TempEmail

  class TempEmailDB

    VERSION = 1_i64

    FOUND = 200
    ERROR = 400
    UNKNOWN = 500
    EXPIRED = 501
    EXPENDED = 502

    @db : DB::Database
    
    def initialize(@config : Config)
      @db = DB.open("sqlite3://#{config.db}")
      upgrade_db(VERSION)
    end

    # returns the code and the value
    def check_address(address : String) : Tuple(Int32, String?)
      begin
        result = @db.query_one("select destination, expiry, forget, remaining_uses from addresses where address = ?",
                               address,
                               as: { destination: String, expiry: Int64?, forget: Int64?, remaining_uses: Int64? })
        destination, expiry, forget, remaining_uses =
                                     result[:destination], result[:expiry], result[:forget], result[:remaining_uses]
        now = Time.now.epoch
        if forget.is_a?(Int64)
          if now > forget
            # if the forget time has expired then pretend we never found it
            @db.exec("delete from addresses where address = ?", address)
            return { UNKNOWN, nil }
            # returning unknonw lets the matcher recreate a new record if it still exists
          end
        end
        if expiry.is_a?(Int64)
          if Time.now.epoch > expiry
            # if it has expired (but not been forgotten) pretend it's unknown but keep the record around
            return { EXPIRED, nil }
          end
        end
        if remaining_uses.is_a?(Int64)
          if remaining_uses > 0
            @db.exec("begin exclusive")
            # we have some remaining uses, decrement the counter then return the address (but not if we are within the grace period)
            result = @db.exec("update addresses set remaining_uses = remaining_uses - 1, last_use = ? where address = ? and ? - last_use > ?",
                              now, address, now, @config.remaining_grace)
            if result.rows_affected > 0
              # now check if we're down to zero uses remaining; if so null out the remaining uses and convert to
              # an expiring address
              remaining_uses = @db.scalar("select remaining_uses from addresses where address = ?",
                                          address)
              if remaining_uses == 0
                @db.exec("update addresses set remaining_uses = NULL, expiry = ? where address = ?",
                         now + @config.remaining_grace, address)
              end
            end
            @db.exec("commit")
            return { FOUND, destination }
          else
            # address exists but we've run out of uses
            return { EXPENDED, nil }
          end
        end
        return { FOUND, destination }
      rescue DB::Error
        return { UNKNOWN, nil }
      end
      # we should never get here if the rest of the code maintains DB integrity, but return something
      # to keep the type system happy
      return { UNKNOWN, nil }
    end

    def add_address(address : String, destination : String, expiry : Int64?, forget : Int64?, remaining_uses : Int64?)
      now = if remaining_uses.nil?
              nil
            else
              Time.now.epoch
            end
      @db.exec("insert into addresses values(?, ?, ?, ?, ?, ?)",
               address, destination, expiry, forget, remaining_uses, now)
    end
    
    def upgrade_db(target_version : Int64)
      # first get the current database version
      version = begin
                  @db.scalar("select version from version").as(Int64)
                rescue SQLite3::Exception
                  0_i64
                end
      if version < 0 || version > VERSION
        raise "internal error: database has version #{version}"
      end
      while version < target_version
        version += 1
        upgrade_to_version(version)
      end
    end

    def upgrade_to_version(version : Int64)
      puts "Upgrade to version #{version}"
      case version
      when 1
        # create initial database
        @db.exec("begin")
        @db.exec("create table version (version integer)")
        @db.exec("insert into version values(?)", 1)
        @db.exec("create table addresses (address text primary key, destination text not null, expiry integer null, forget integer null, remaining_uses integer null, last_use integer null)")
        @db.exec("commit")
      else
        raise ArgumentError.new("attempt to upgrade to unknown database version number #{version}")
      end
    end
  end

end
