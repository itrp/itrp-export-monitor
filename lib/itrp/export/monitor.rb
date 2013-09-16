require 'gem_config'
require 'logger'

module Itrp
  module Export
    module Monitor
      include GemConfig::Base

      with_configuration do
        has :logger, classes: ::Logger, default: ::Logger.new(STDOUT)

        has :name, classes: String
        has :daemonize, classes: [TrueClass, FalseClass], default: false
        has :root, classes: String
        has :id, classes: Fixnum
        has :ids, classes: Array
        has :to, classes: String

        has :to_ftp, classes: String
        has :ftp_user_name, classes: String
        has :ftp_password, classes: String

        has :imap_address, classes: String, default: 'imap.googlemail.com'
        has :imap_port, classes: Fixnum, default: 993
        has :imap_ssl, classes: [TrueClass, FalseClass], default: true
        has :imap_user_name, classes: String
        has :imap_password, classes: String

        has :imap_mailbox, classes: String, default: 'INBOX'
        has :imap_archive, classes: String, default: '[Gmail]/All Mail'
      end

      def self.logger
        configuration.logger
      end
    end
  end
end
