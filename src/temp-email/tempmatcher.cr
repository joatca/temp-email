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
      when /^(\d+)$/
        @expiry_seconds = $1.to_i64
      when /^(\d+)m$/
        @expiry_seconds = $1.to_i64 * 60
      when /^(\d+)h$/
        @expiry_seconds = $1.to_i64 * 60 * 60
      when /^(\d+)d$/
        @expiry_seconds = $1.to_i64 * 60 * 60 * 24
      when /^(\d+)x$/
        @max_emails = $1.to_i64
      when /^!(\d+)d$/
        @forget_seconds = $1.to_i64 * 60 * 60 * 24
      else
        raise ArgumentError.new("unknown parameter #{parameter}")
      end
    end
      
  end

end
