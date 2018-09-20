module TempEmail

  lib C
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
    @max_emails : UInt32?
    @expiry_seconds : UInt32?
    @regex : Regex

    property max_emails, expiry_seconds, regex
    
    def initialize(pattern = "", @max_emails = nil, @expiry_seconds = nil)
      @regex = Regex.new(pattern)
    end

    def set_parameter(parameter : String)
    end
      
  end
       
  class Config

    property port, matchers, uid, config_file
    
    def initialize
      @port = 9099
      default_matcher = TempMatcher.new
      @matchers = Array(TempMatcher).new
      
      @uid = C.geteuid
      @config_file = if @uid == 0
                        "/etc/temp-emailrc"
                     else
                       pw = C.getpwuid(@uid)
                       raise "can't get home directory for UID #{@uid}" if pw == Pointer(C::Passwd).null
                       String.new(pw.value.pw_dir) + "/.temp-emailrc"
                     end
      begin
        File.open(@config_file, "r") do |cfile|
          cfile.each_line.each_with_index do |line, linenum|
            next if line =~ /^\s*#/ # skip comments
            next if line =~ /^\s*$/ # skip blanks
            # because we skipped blanks and comments, anything left must have at least one word command
            cline = line.gsub(/^\s+/, "").gsub(/\s+$/, "").split
            # ... so the [0] can't fail at runtime, and the [1..-1] is safe even with 1-element arrays
            command, args = cline[0], cline[1..-1]
            case command
            when "port"
              config_err(linenum, line, "need one port number") unless args.size == 1
              begin
                @port = args[0].to_i
                raise ArgumentError.new if @port <= 0
              rescue ArgumentError
                config_err(linenum, line, "port number must be a positive integer")
              end
            when "*"
              config_err(linenum, line, "need at least one default parameter") unless args.size > 0
              args.each do |arg|
                begin
                  default_matcher.set_parameter(arg)
                rescue e : ArgumentError
                  config_err(linenum, line, e.message.to_s)
                end
              end
            when /^\/(.*)\/$/
              matcher = TempMatcher.new($1)
              args.each do |arg|
                begin
                  matcher.set_parameter(arg)
                rescue e : ArgumentError
                  config_err(linenum, line, e.message.to_s)
                end
              end
              matchers << matcher
            end
          end
        end
      rescue e : Errno
        raise "unable to read config file \"#{@config_file}\""
      end
    end

    def config_err(linenum : Int, line : String, message : String)
      raise "At line #{linenum+1}: #{line}\n  #{message}"
    end
  end

end
