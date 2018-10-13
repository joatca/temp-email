module TempEmail

  lib C
    # required to get home directories
    fun geteuid : UInt32
       
    struct Passwd
      pw_name, pw_passwd : LibC::Char*
               pw_uid : LibC::UidT
      pw_gid : LibC::GidT
      pw_gecos, pw_dir, pw_shell : LibC::Char*
    end

    fun getpwuid(uid : UInt32) : Passwd*
  end

  class TempMatcher
    @destination : String?
    @regex : Regex
    @max_emails : Int64? # how many emails are allowed to this address?
    @expiry_seconds : Int64? # after how long does this address expire?
    @forget_seconds : Int64? # after how long is any record of this address forgotten?

    property max_emails, expiry_seconds, forget_seconds, regex, destination
    
    def initialize(pattern = "", @max_emails = nil, @expiry_seconds = nil)
      @regex = Regex.new(pattern)
    end

    def set_defaults(other : self)
      @max_emails, @expiry_seconds, @forget_seconds =
                                    other.max_emails, other.expiry_seconds, other.forget_seconds
    end
    
    def set_parameter(parameter : String)
      case parameter
      when /^(!)?(\d+)([smhd])?$/
        time = case $3
               when "m"
                 $2.to_i64 * 60
               when "h"
                 $2.to_i64 * 60 * 60
               when "d"
                 $2.to_i64 * 60 * 60 * 24
               else
                 $2.to_i64
               end
        if $~[1]?
          @forget_seconds = time
        else
          @expiry_seconds = time
        end
      when /^(\d+)x$/
        @max_emails = $1.to_i64
      else
        raise ArgumentError.new("unknown parameter #{parameter}")
      end
    end

    def check_match(address : String, db : TempEmailDB) : String?
      if @regex =~ address
        # matches the address, create the record and return the destination address
        now = Time.now.epoch
        remaining = if @max_emails.nil?
                      nil
                    else
                      @max_emails.as(Int64) - 1
                    end
        expiry = if @expiry_seconds.nil?
                   nil
                 else
                   now + @expiry_seconds.as(Int64)
                 end
        forget = if @forget_seconds.nil?
                   nil
                 else
                   now + @forget_seconds.as(Int64)
                 end
        db.add_address(address, @destination.as(String), expiry, forget, remaining)
        @destination
      else
        nil
      end
    end
      
  end

end
