require 'fileutils'
require 'mail'
require 'open-uri'
require 'net/ftp'

require 'active_support/core_ext/module/aliasing.rb'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try.rb'
require 'active_support/core_ext/hash/indifferent_access'

require 'clacks'
require 'itrp'

require 'itrp/export/monitor'
require 'itrp/export/monitor/clacks_fix'
require 'itrp/export/monitor/version'
require 'itrp/export/monitor/mail'

module Itrp
  module Export
    module Monitor

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
      #  - daemonize:      Set to +true+ to run in daemon mode; not available on Windows (default: false)
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
      class Service

        class << self
          def run
            # create the export monitor as a singleton
            @singleton = Itrp::Export::Monitor::Service.new
            # generate clacks file
            clacks_config_filename = @singleton.generate_clacks_config
            # start clacks with the generated config
            args = ['-c', clacks_config_filename]
            args << '-D' if @singleton.option(:daemonize)
            Clacks::Command.new(args).exec
            # returns the singleton instance
            @singleton
          end

          def process(mail)
            @singleton.process(mail)
          end
        end

        def initialize
          @options = Itrp::Export::Monitor.configuration.current
          @options[:ids] = (@options[:ids] || []) + [@options[:id]].flatten.compact.map(&:to_i)
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
          mail = Itrp::Export::Monitor::Mail.new(mail)
          if option(:ids).include?(mail.export_id)
            begin
              @logger.info { "Processing ITRP Export mail:\n  Subject: #{mail.original.subject}\n  Export ID: #{mail.export_id}\n  Token: #{mail.token}\n  URI: #{mail.download_uri}" }
              store_export(mail)
            rescue ::Exception => ex
              @logger.error { "Processing failed: #{ex.message}\n  #{ex.backtrace.join("\n  ")}" }
              mail.ignore # leave mail in the mailbox
            end
          else
            @logger.info { mail.export_id ? "Skipping mail. ITRP Export ID #{mail.export_id} not configured for monitoring" : "Skipping mail. Not an ITRP Export mail: #{mail.original.subject}" }
            mail.ignore # leave mail in the mailbox
          end
        end

        # Generate a clacks config file based on the export config
        def generate_clacks_config
          clacks_config_filename = "#{dir(:tmp)}/clacks_config.#{monitor_id}.rb"
          File.open(clacks_config_filename, 'w') do |clacks_config|
            clacks_config.write(<<EOF)
# -- DO NOT EDIT --
# Generated by the Export Monitor

pid "#{dir(:pids)}/#{monitor_id}.pid"
stdout_path "#{dir(:log)}/#{monitor_id}.log"
stderr_path "#{dir(:log)}/#{monitor_id}.log"

imap({
  address:    '#{option(:imap_address)}',
  port:       #{option(:imap_port)},
  user_name:  '#{option(:imap_user_name)}',
  password:   '#{option(:imap_password)}',
  enable_ssl: #{option(:imap_ssl)}
})

find_options({
  mailbox:           '#{option(:imap_mailbox)}',
  archivebox:        '#{option(:imap_archive)}',
  keys:              'FROM ITRP HEADER X-ITRP-ExportID ""',
  delete_after_find: true # Note that only the processed export mails will be deleted
})

on_mail do |mail|
  Itrp::Export::Monitor::Service.process(mail)
end
EOF
          end
          clacks_config_filename
        end

        private

        def store_export(mail)
          # download export file to the downloads directory
          local_filename = download_export(mail)
          # copy the file to the :to directory
          copy_export(local_filename) if option(:to)
          # ftp the file
          ftp_export(local_filename) if option(:to_ftp)
        end

        def download_export(mail)
          local_filename = "#{dir(:downloads)}/#{mail.filename}"
          File.open(local_filename, 'w') { |local| open(mail.download_uri) { |remote| local.write(remote.read) }}
          local_filename
        end

        def copy_export(local_filename)
          FileUtils.mkpath(option(:to))
          to_filename = "#{option(:to)}/#{File.basename(local_filename)}"
          FileUtils.copy(local_filename, "#{to_filename}.in_progress")
          FileUtils.move("#{to_filename}.in_progress", to_filename)
          @logger.info { "Copied export '#{local_filename}' to '#{to_filename}'" }
        end

        def ftp_export(local_filename)
          remote_filename = File.basename(local_filename)
          Net::FTP.open(option(:to_ftp), option(:ftp_user_name), option(:ftp_password)) do |ftp|
            ftp.putbinaryfile(local_filename, "#{remote_filename}.in_progress")
            ftp.rename("#{remote_filename}.in_progress", remote_filename)
          end
          @logger.info { "FTP export '#{local_filename}' to '#{option(:to_ftp)}/#{remote_filename}'" }
        end

        def dir(subdir)
          directory = File.expand_path(subdir.to_s, option(:root))
          FileUtils.mkpath(directory)
          directory
        end

        def monitor_id
          @monitor_id ||= "export_monitor.#{option(:ids).map(&:to_s).join('.')}"
        end
      end
    end
  end
end