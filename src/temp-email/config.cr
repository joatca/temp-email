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
  
  class Config

    def initialize
      @uid = C.geteuid
      @config_file = if @uid == 0
                        "/etc/temp-emailrc"
                     else
                       pw = C.getpwuid(@uid)
                       raise "can't get home directory for UID #{@uid}" if pw == Pointer(C::Passwd).null
                       String.new(pw.value.pw_dir) + "/.temp-emailrc"
                     end
    end

  end

end
