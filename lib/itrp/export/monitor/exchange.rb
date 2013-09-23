require 'fileutils'
require 'net/ftp'
require 'zip'
require 'csv'

module Itrp
  module Export
    module Monitor

      class Exchange
        attr_accessor :options, :fullpath, :basename

        def initialize(export_filename, options)
          @options = options
          @options[:to_ftp_dir].gsub!('\\', '/')
          @fullpath = export_filename
          @basename = File.basename(export_filename)
          @logger = @options[:logger]
        end

        def transfer
          files = transfer_files
          local_transfer(files) unless option(:to).blank?
          ftp_transfer(files) unless option(:to_ftp).blank?
        end

        private

        def option(key)
          @options[key]
        end

        # return an hash with files that need to be transferred {<local file name>: <remote file path>}
        def transfer_files
          # unzip if needed
          files = option(:unzip) && @fullpath =~ /\.zip$/ ? unzip : {@fullpath => @basename}
          if option(:unzip)
            # prepend the export type as a subdirectory in the target path
            files.each_value{ |target| target.insert(0, "#{target[/.*-(.*)\.csv$/, 1]}/")} if option(:sub_dirs)
            # convert the CSV files
            files.each_key{ |source| convert_csv(source) } unless [:csv_row_sep, :csv_col_sep, :csv_quote_char, :csv_value_proc].all?{ |csv_option| option(csv_option).blank? }
          end
          files
        end

        # unzip all files to tmp directory
        def unzip
          files = {}
          unzip_dir = @fullpath[0..-5]
          FileUtils.mkpath(unzip_dir)
          Zip::File.open(@fullpath) do |zipfile|
            zipfile.each do |entry|
              next unless entry.file?
              full_source_path = "#{unzip_dir}/#{entry.name}"
              entry.extract(full_source_path)
              files[full_source_path] = entry.name
            end
          end
          files
        end

        # Convert the CSV files using the CSV options
        def convert_csv(original_csv)
          csv_options = {}
          csv_options[:col_sep] = option(:csv_col_sep) unless option(:csv_col_sep).blank?
          csv_options[:row_sep] = option(:csv_row_sep) unless option(:csv_row_sep).blank?
          csv_options[:quote_char] = option(:csv_quote_char) unless option(:csv_quote_char).blank?
          value_converter = option(:csv_value_proc)

          converted_csv = "#{original_csv}.converting"
          CSV.open(converted_csv, 'wb', csv_options) do |csv|
            CSV.foreach(original_csv) do |row|
              row = row.map{ |value| value.blank? ? '' : value_converter.call(value) } if value_converter
              csv << row
            end
          end
          FileUtils.remove(original_csv)
          FileUtils.move(converted_csv, original_csv)
        end

        def local_transfer(files)
          files.each do |full_source_path, relative_target_path|
            full_target_path = "#{option(:to)}/#{relative_target_path}"
            local_copy(full_source_path, full_target_path)
          end
          @logger.info { "Copied #{files.size} file(s) from '#{@fullpath}' to '#{option(:to)}'" }
        end

        # copy a local file and make sure the directories are created
        def local_copy(source, target)
          FileUtils.mkpath(File.dirname(target))
          FileUtils.copy(source, "#{target}.in_progress")
          FileUtils.move("#{target}.in_progress", target)
        end

        def ftp_transfer(files)
          Net::FTP.open(option(:to_ftp), option(:ftp_user_name), option(:ftp_password)) do |ftp|
            files.each do |full_source_path, relative_target_path|
              ftp_copy(ftp, full_source_path, "#{option(:to_ftp_dir)}/#{relative_target_path}")
            end
          end
          @logger.info { "Copied #{files.size} file(s) from '#{@fullpath}' to '#{option(:to_ftp)}/#{option(:to_ftp_dir)}'" }
        end

        # copy a file from the local disk to a remote FTP server
        # it is possible to use a path in the remote file, e.g. 'dir1/dir2/remote_file.txt'
        def ftp_copy(ftp, local_file, remote_file)
          in_ftp_dir(ftp, File.dirname(remote_file)) do |_ftp|
            basename = File.basename(remote_file)
            _ftp.putbinaryfile(local_file, "#{basename}.in_progress")
            _ftp.rename("#{basename}.in_progress", basename)
          end
        end

        # move to the given subdirectory (create directories on the fly) and yield
        # the ftp directory will be reset afterwards
        def in_ftp_dir(ftp, path, &block)
          if path.blank? || path == '.'
            yield ftp
          else
            pwd = ftp.pwd
            begin
              # move to the directory, ignore / at start or end, and paths with only dots like . and ..
              path.split('/').reject{|dir| dir.blank? || dir =~ /\.+/}.each do |dir|
                begin ftp.mkdir(dir); rescue ::Exception => e; end
                ftp.chdir(dir)
              end
              yield ftp
            ensure
              ftp.chdir(pwd)
            end
          end
        end

      end
    end
  end
end

