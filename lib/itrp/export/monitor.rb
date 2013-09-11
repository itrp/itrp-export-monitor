%w(itrp itrp/export).each{ |f| require f }
%w(version mail).each{ |f| require "itrp/export/#{f}" }

# cherry-pick some core extensions from active support
require 'active_support/core_ext/module/aliasing.rb'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try.rb'
require 'active_support/core_ext/hash/indifferent_access'

module Itrp
  module Export

    # Configuration for ITRP Export:
    #   Itrp::Export.configure do |export|
    #     export.name           = 'people_export'
    #     export.root           = File.expand_path('../exports', __FILE__)
    #     export.id             = 8713
    #     export.to             = "#{export.root}/people"
    #     export.imap_user_name = 'test.exports@gmail.com'
    #     export.imap_password  = 'secret'
    #     ...
    #   end
    #
    # Start the ITRP Export Monitor:
    #   Itrp::Export::Monitor.run
    #
    # All options available:
    #  - logger:         The Ruby Logger instance, default: Logger.new(STDOUT)
    #  - daemon:         Set to +true+ to run in daemon mode; not available on Windows (default: false)
    #  - name:           *required* The name of the export
    #  - root:           *required* The root directory to store export monitor logs, pids and downloads
    #  - id/ids:         *required* The id(s) of the scheduled exports to monitor
    #  - to:             Location to store export files (default = <root>/ready)
    #  - to_ftp:         The address of the FTP server to sent the completed downloads to
    #  - ftp_user_name:  The user name to access the FTP server
    #  - ftp_password:   The password to access the FTP server
    #  - imap_address:   The address of the IMAP mail server (default: 'imap.googlemail.com')
    #  - imap_port:      The port of the IMAP mail server (default: 993)
    #  - imap_ssl:       Set to +false+ to disabled SSL (default: true)
    #  - imap_user_name: *required* The user name to access the IMAP server
    #  - imap_password:  *required* The password to access the IMAP server
    #  - imap_mailbox:   The mailbox to monitor for ITRP export mails (default: 'INBOX')
    #  - imap_archive:   The archive mailbox to store the processed ITRP export mails (default: '[Gmail]/All Mail')
    class Monitor

      class << self
        def run
          # make sure the export config is OK
          @singleton = Itrp::Export::Monitor.new
          # generate clacks file

          # start clacks

          # return the singleton instance
          @singleton
        end

        def process(mail)
          @singleton.process(mail)
        end
      end

      def initialize
        @options = Itrp::Export.configuration.current
        @options[:ids] = (@options[:ids] || []) + [@options[:id]].flatten.compact
        [:name, :root, :ids, :imap_user_name, :imap_password].each do |required_option|
          raise ::Itrp::Exception.new("Missing required configuration option #{required_option}") if option(required_option).blank?
        end
        @logger = @options[:logger]
      end

      # Retrieve an option
      def option(key)
        @options[key]
      end

      def process(mail)
        mail = Itrp::Export::Mail.new(mail)
        if @options.ids.include?(mail.export_id)
          # download export file

        else
          mail.ignore # leave mail in the mailbox
        end
      end
    end

  end
end
