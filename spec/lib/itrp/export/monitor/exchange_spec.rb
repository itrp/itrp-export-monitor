require 'spec_helper'

describe Itrp::Export::Monitor::Exchange do
  before(:each) do
    # default configuration for testing
    @options = {
      root: "#{@spec_dir}/tmp/exports",
      to: "#{@spec_dir}/tmp/copy_to",

      to_ftp:        'ftp://ftp.example.com:888',
      to_ftp_dir:    '.',
      ftp_user_name: 'ftp user',
      ftp_password:  'ftp password',

      logger: Itrp::Export::Monitor.configuration.logger
    }
  end

  # create an exchange object for the given fixture
  # e.g. exchange = exchange('20130923-072313-export.zip')
  def exchange(fixture = 'dummy.csv', options = @options)
    export_file = "#{options[:root]}/#{fixture}"
    FileUtils.copy("#{@fixture_dir}/#{fixture}", export_file)
    Itrp::Export::Monitor::Exchange.new(export_file, options)
  end

  context 'copy' do
    before(:each) do
      @exchange = exchange()
      @exchange.options[:to_ftp] = nil
    end

    it 'should copy the export file to another location' do
      expect_log("Copied export '#{@exchange.fullpath}' to '#{@options[:to]}/dummy.csv'")

      @exchange.transfer

      File.read("#{@options[:to]}/dummy.csv").should == 'exported content'
    end
  end

  context 'ftp' do
    before(:each) do
      @exchange = exchange()
      @exchange.options[:to] = nil
    end

    it 'should FTP the export file' do
      expect_log("FTP export '#{@exchange.fullpath}' to '#{@options[:to_ftp]}/./dummy.csv'")

      ftp = double('Net::FTP')
      expect(ftp).to receive(:putbinaryfile).with(@exchange.fullpath, 'dummy.csv.in_progress')
      expect(ftp).to receive(:rename).with('dummy.csv.in_progress', 'dummy.csv')
      expect(Net::FTP).to receive(:open).with('ftp://ftp.example.com:888', 'ftp user', 'ftp password').and_yield(ftp)

      @exchange.transfer
    end

    it 'should use the to_ftp_dir option' do
      @exchange.options[:to_ftp_dir] = 'dir1/dir2'

      expect_log("FTP export '#{@exchange.fullpath}' to '#{@options[:to_ftp]}/dir1/dir2/dummy.csv'")

      ftp = double('FTP')
      expect(ftp).to receive(:pwd).once.with().and_return('/root/dir')
      expect(ftp).to receive(:mkdir).with('dir1').and_raise(Exception.new('directory already exists'))
      expect(ftp).to receive(:chdir).with('dir1')
      expect(ftp).to receive(:mkdir).with('dir2')
      expect(ftp).to receive(:chdir).with('dir2')
      expect(ftp).to receive(:putbinaryfile).with(@exchange.fullpath, 'dummy.csv.in_progress')
      expect(ftp).to receive(:rename).with('dummy.csv.in_progress', 'dummy.csv')
      expect(ftp).to receive(:chdir).with('/root/dir')
      expect(Net::FTP).to receive(:open).with('ftp://ftp.example.com:888', 'ftp user', 'ftp password').and_yield(ftp)

      @exchange.transfer
    end
  end
end