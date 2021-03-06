require 'gem_config'
require 'logger'
require 'mail'

require 'itrp/client' # this will load CA Certificate bundle
require 'clacks'

require 'itrp/export/monitor/service'
require 'itrp/export/monitor/version'
require 'itrp/export/monitor/mail'
require 'itrp/export/monitor/exchange'

require 'active_support/core_ext/module/aliasing.rb'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try.rb'
require 'active_support/core_ext/hash/indifferent_access'

module Itrp
  module Export

    # Configuration for ITRP Export Monitor:
    #   Itrp::Export::Monitor.configure do |export|
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
    #  - daemonize:      Set to +true+ to run in daemon mode; not available on Windows (default: false)
    #  - name:           *required* The name of the export
    #  - root:           *required* The root directory to store export monitor logs, pids and downloads
    #  - id/ids:         *required* The id(s) of the scheduled exports to monitor
    #  - to:             Location to store export files (default = <root>/ready)
    #  - to_ftp:         The address of the FTP server to sent the completed downloads to
    #  - to_ftp_dir:     The subdirectory on the FTP server (default = '.')
    #  - ftp_user_name:  The user name to access the FTP server
    #  - ftp_password:   The password to access the FTP server
    #  - imap_address:   The address of the IMAP mail server (default: 'imap.googlemail.com')
    #  - imap_port:      The port of the IMAP mail server (default: 993)
    #  - imap_ssl:       Set to +false+ to disabled SSL (default: true)
    #  - imap_user_name: *required* The user name to access the IMAP server
    #  - imap_password:  *required* The password to access the IMAP server
    #  - imap_mailbox:   The mailbox to monitor for ITRP export mails (default: 'INBOX')
    #  - imap_archive:   The archive mailbox to store the processed ITRP export mails (default: '[Gmail]/All Mail')
    #  - imap_search:    The query used to search for emails from ITRP containing export data (default: `'FROM ITRP HEADER X-ITRP-ExportID ""'`)
    #  - on_exception:   A Proc that takes an exception and the mail as an argument: Proc.new{ |ex, mail| ... }
    module Monitor
      include GemConfig::Base

      with_configuration do
        has :logger, classes: ::Logger, default: ::Logger.new(STDOUT)

        has :daemonize, classes: [TrueClass, FalseClass], default: false
        has :exit_when_idle, classes: Fixnum, default: -1
        has :root, classes: String
        has :id, classes: Fixnum
        has :ids, classes: Array
        has :unzip, classes: [TrueClass, FalseClass], default: true
        has :sub_dirs, classes: [TrueClass, FalseClass], default: false

        has :to, classes: String

        has :to_ftp, classes: String
        has :to_ftp_dir, classes: String, default: '.'
        has :ftp_user_name, classes: String
        has :ftp_password, classes: String

        has :imap_address, classes: String, default: 'imap.googlemail.com'
        has :imap_port, classes: Fixnum, default: 993
        has :imap_ssl, classes: [TrueClass, FalseClass], default: true
        has :imap_user_name, classes: String
        has :imap_password, classes: String

        has :imap_mailbox, classes: String, default: 'INBOX'
        has :imap_archive, classes: String, default: '[Gmail]/All Mail'
        has :imap_search, classes: String, default: 'FROM ITRP HEADER X-ITRP-ExportID ""'

        has :on_exception, classes: Proc

        has :csv_row_sep, classes: String
        has :csv_col_sep, classes: String
        has :csv_quote_char, classes: String
        has :csv_value_proc, classes: Proc
      end

      class << self

        def run
          # create the export monitor as a singleton
          @service = Itrp::Export::Monitor::Service.new
          # generate clacks file
          clacks_config_filename = @service.generate_clacks_config
          # start clacks with the generated config
          args = ['-c', clacks_config_filename]
          args << '-D' if @service.option(:daemonize)
          Clacks::Command.new(args).exec
          # return the singleton instance
          @service
        end

        def process(mail)
          @service.process(mail)
        end

        def logger
          configuration.logger
        end
      end

    end
  end
end
