require 'fileutils'
require 'net/ftp'

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
          # copy the file to the :to directory
          copy_export if option(:to)
          # ftp the file
          ftp_export if option(:to_ftp)
        end

        private

        def option(key)
          @options[key]
        end

        def copy_export
          FileUtils.mkpath(option(:to))
          to_filename = "#{option(:to)}/#{@basename}"
          FileUtils.copy(@fullpath, "#{to_filename}.in_progress")
          FileUtils.move("#{to_filename}.in_progress", to_filename)
          @logger.info { "Copied export '#{@fullpath}' to '#{to_filename}'" }
        end

        def ftp_export
          Net::FTP.open(option(:to_ftp), option(:ftp_user_name), option(:ftp_password)) do |ftp|
            ftp_copy(ftp, @fullpath, "#{option(:to_ftp_dir)}/#{@basename}")
          end
          @logger.info { "FTP export '#{@fullpath}' to '#{option(:to_ftp)}/#{option(:to_ftp_dir)}/#{@basename}'" }
        end

        def dir(subdir)
          directory = File.expand_path(subdir.to_s, option(:root))
          FileUtils.mkpath(directory)
          directory
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

