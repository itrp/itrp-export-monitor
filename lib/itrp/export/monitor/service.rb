require 'fileutils'
require 'open-uri'

module Itrp
  module Export
    module Monitor

      class Service

        def initialize
          @failed_exports = Set.new
          @missing_export_ids = Set.new
          @options = Itrp::Export::Monitor.configuration.current
          @options[:ids] = (@options[:ids] || []) + [@options[:id]].flatten.compact.map(&:to_i)
          [:root, :ids, :imap_user_name, :imap_password].each do |required_option|
            raise ::Itrp::Exception.new("Missing required configuration option #{required_option}") if option(required_option).blank?
          end
          [:sub_dirs, :csv_row_sep, :csv_col_sep, :csv_quote_char, :csv_value_proc].each do |unzip_dependent_option|
            raise ::Itrp::Exception.new("Configuration option #{unzip_dependent_option} is only available when unzip is true") unless option(unzip_dependent_option).blank?
          end unless @options[:unzip]
          raise ::Itrp::Exception.new("Configuration option csv_quote_char must be 1 character long") unless option(:csv_quote_char).blank? || option(:csv_quote_char).length == 1
          @logger = @options[:logger]
        end

        # Retrieve an option
        def option(key)
          @options[key]
        end

        def process(mail)
          mail = Itrp::Export::Monitor::Mail.new(mail)
          return if @failed_exports.include?(mail.download_uri)

          if option(:ids).include?(mail.export_id)
            begin
              @logger.info { "Processing ITRP Export mail:\n  Subject: #{mail.original.subject}\n  Export ID: #{mail.export_id}\n  Token: #{mail.token}\n  URI: #{mail.download_uri}" }
              store_export(mail)
            rescue ::Exception => ex
              @failed_exports.add(mail.download_uri)
              @logger.error { "Processing of mail '#{mail.original.subject}' failed: #{ex.message}\n  #{ex.backtrace.join("\n  ")}" }
              handle_exception(ex, mail)
              mail.ignore # leave mail in the mailbox
            end
          else
            mail.ignore # leave mail in the mailbox
            unless @missing_export_ids.include?(mail.export_id)
              @missing_export_ids.add(mail.export_id)
              @logger.info { mail.export_id ? "Skipping mail. ITRP Export ID #{mail.export_id} not configured for monitoring" : "Skipping mail. Not an ITRP Export mail: #{mail.original.subject}" }
            end
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
  Itrp::Export::Monitor.process(mail)
end
EOF
          end
          clacks_config_filename
        end

        private

        def store_export(mail)
          # download export file to the downloads directory
          export_file_name = download_export(mail)
          # and tranfer the files
          Itrp::Export::Monitor::Exchange.new(export_file_name, @options).transfer
        end

        def download_export(mail)
          local_filename = "#{dir(:downloads)}/#{mail.filename}"
          File.open(local_filename, 'wb') { |f| f.write(open(mail.download_uri).read) }
          local_filename
        end

        def dir(subdir)
          directory = File.expand_path(subdir.to_s, option(:root))
          FileUtils.mkpath(directory)
          directory
        end

        def monitor_id
          @monitor_id ||= "export_monitor.#{option(:ids).map(&:to_s).join('.')}"
        end

        def handle_exception(ex, mail)
          proc = option(:on_exception)
          if proc
            begin
              proc.call(ex, mail)
            rescue ::Exception => another_exception
              @logger.error { "Exception occurred in exception handling: #{another_exception.message}\n  #{another_exception.backtrace.join("\n  ")}" }
            end
          end
        end
      end
    end
  end
end
