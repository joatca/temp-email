require "syslog"

module TempEmail

  class Logger

    def self.start(ch : Channel(String))
      Syslog.prefix = "temp-email"
      Syslog.facility = Syslog::Facility::Mail
      loop do
        message = ch.receive
        Syslog.notice(message)
      end
    end
    
  end

end
