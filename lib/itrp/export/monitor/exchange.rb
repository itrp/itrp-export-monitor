require 'fileutils'
require 'net/ftp'
require 'zip'

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
          files = option(:unzip) && @fullpath =~ /\.zip$/ ? unzip : {@fullpath => @basename}
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
          in_ftp_dir(ftp, File.dirname(remote_file)) do |ftp|
            basename = File.basename(remote_file)
            ftp.putbinaryfile(local_file, "#{basename}.in_progress")
            ftp.rename("#{basename}.in_progress", basename)
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

