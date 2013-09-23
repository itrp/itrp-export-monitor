require 'spec_helper'

describe Itrp::Export::Monitor::Exchange do
  before(:each) do
    # default configuration for testing
    @options = {
      root: "#{@spec_dir}/tmp/exports",
      to: "#{@spec_dir}/tmp/copy_to",
      unzip: true,

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

  context 'unzip' do
    before(:each) do
      @exchange = exchange('20130923-072313-export.zip')
    end

    it 'should not unzip when setting the option to false' do
      @exchange.options[:unzip] = false
      @exchange.options[:to_ftp] = nil
      expect_log("Copied 1 file(s) from '#{@exchange.fullpath}' to '#{@options[:to]}'")

      @exchange.transfer

      File.exists?("#{@options[:to]}/20130923-072313-export.zip").should == true
    end

    it 'should unzip to local disk' do
      @exchange.options[:to_ftp] = nil
      expect_log("Copied 4 file(s) from '#{@exchange.fullpath}' to '#{@options[:to]}'")

      @exchange.transfer

      File.read("#{@options[:to]}/5-20130923-072312-calendars.csv").should include( %(30,,,24x7 except Sunday 5:00am until Noon,mon,00:00,24:00\n))
      File.read("#{@options[:to]}/5-20130923-072312-organizations.csv").should include( %(27,,,0,Microsoft Corporation,0,,,,,"Global product licensing sales contact for Widget International, Corp.: Brian Waymore\nEmail: brian.waymore@microsoft.com"\n))
      File.read("#{@options[:to]}/5-20130923-072312-organizations_contact_details.csv").should include( %(International Business Machines Corporation (IBM),,,,street,590 Madison Avenue,New York,NY,10022,US,0\n))
      File.read("#{@options[:to]}/5-20130923-072312-sites.csv").should include( %(14,,,0,IT Training Facility,"4465 San Felipe Street, Suite 1508",Houston,TX,77027,US,Central Time (US & Canada),\n))
    end

    it 'should unzip to FTP' do
      @exchange.options[:to] = nil
      expect_log("Copied 4 file(s) from '#{@exchange.fullpath}' to '#{@options[:to_ftp]}/.'")

      ftp = double('Net::FTP')
      ['5-20130923-072312-calendars.csv', '5-20130923-072312-organizations.csv', '5-20130923-072312-organizations_contact_details.csv', '5-20130923-072312-sites.csv'].each do |csv|
        expect(ftp).to receive(:putbinaryfile).with("#{@exchange.fullpath[0..-5]}/#{csv}", "#{csv}.in_progress")
        expect(ftp).to receive(:rename).with("#{csv}.in_progress", csv)
      end
      expect(Net::FTP).to receive(:open).with('ftp://ftp.example.com:888', 'ftp user', 'ftp password').and_yield(ftp)

      @exchange.transfer
    end

    context 'sub_dirs' do
      before(:each) do
        @exchange.options[:sub_dirs] = true
      end

      it 'should unzip and use sub directories on local disk' do
        @exchange.options[:to_ftp] = nil
        expect_log("Copied 4 file(s) from '#{@exchange.fullpath}' to '#{@options[:to]}'")

        @exchange.transfer

        File.read("#{@options[:to]}/calendars/5-20130923-072312-calendars.csv").should include( %(30,,,24x7 except Sunday 5:00am until Noon,mon,00:00,24:00\n))
        File.read("#{@options[:to]}/organizations/5-20130923-072312-organizations.csv").should include( %(27,,,0,Microsoft Corporation,0,,,,,"Global product licensing sales contact for Widget International, Corp.: Brian Waymore\nEmail: brian.waymore@microsoft.com"\n))
        File.read("#{@options[:to]}/organizations_contact_details/5-20130923-072312-organizations_contact_details.csv").should include( %(International Business Machines Corporation (IBM),,,,street,590 Madison Avenue,New York,NY,10022,US,0\n))
        File.read("#{@options[:to]}/sites/5-20130923-072312-sites.csv").should include( %(14,,,0,IT Training Facility,"4465 San Felipe Street, Suite 1508",Houston,TX,77027,US,Central Time (US & Canada),))
      end

      it 'should unzip and use sub directories for FTP' do
        @exchange.options[:to] = nil
        expect_log("Copied 4 file(s) from '#{@exchange.fullpath}' to '#{@options[:to_ftp]}/.'")

        ftp = double('Net::FTP')
        expect(ftp).to receive(:pwd).with().and_return('/root').exactly(4).times
        [%w(calendars                     5-20130923-072312-calendars.csv),
         %w(organizations                 5-20130923-072312-organizations.csv),
         %w(organizations_contact_details 5-20130923-072312-organizations_contact_details.csv),
         %w(sites                         5-20130923-072312-sites.csv)].each do |sub_dir, csv|
          expect(ftp).to receive(:mkdir).with(sub_dir)
          expect(ftp).to receive(:chdir).with(sub_dir)
          expect(ftp).to receive(:putbinaryfile).with("#{@exchange.fullpath[0..-5]}/#{csv}", "#{csv}.in_progress")
          expect(ftp).to receive(:rename).with("#{csv}.in_progress", csv)
        end
        expect(ftp).to receive(:chdir).with('/root').exactly(4).times

        expect(Net::FTP).to receive(:open).with('ftp://ftp.example.com:888', 'ftp user', 'ftp password').and_yield(ftp)

        @exchange.transfer
      end
    end

    context 'csv conversion' do
      before(:each) do
        @exchange.options[:csv_row_sep] = "##\n"
        @exchange.options[:csv_col_sep] = '|'
        @exchange.options[:csv_quote_char] = ':'
        @exchange.options[:csv_value_proc] = Proc.new{ |value| value.gsub(/\r?\n/, '<newline>') }
      end

      it 'should convert all CSV files' do
        @exchange.options[:to_ftp] = nil
        expect_log("Copied 4 file(s) from '#{@exchange.fullpath}' to '#{@options[:to]}'")

        @exchange.transfer

        File.read("#{@options[:to]}/5-20130923-072312-calendars.csv").should include( %(30|::|::|:24x7 except Sunday 5::00am until Noon:|mon|:00::00:|:24::00:##\n))
        File.read("#{@options[:to]}/5-20130923-072312-organizations.csv").should include( %(27|::|::|0|Microsoft Corporation|0|::|::|::|::|:Global product licensing sales contact for Widget International, Corp.:: Brian Waymore<newline>Email:: brian.waymore@microsoft.com:##\n))
        File.read("#{@options[:to]}/5-20130923-072312-organizations_contact_details.csv").should include( %(International Business Machines Corporation (IBM)|::|::|::|street|590 Madison Avenue|New York|NY|10022|US|0##\n))
        File.read("#{@options[:to]}/5-20130923-072312-sites.csv").should include( %(14|::|::|0|IT Training Facility|4465 San Felipe Street, Suite 1508|Houston|TX|77027|US|Central Time (US & Canada)|::##))
      end
    end
  end

  context 'local transfer' do
    before(:each) do
      @options[:to_ftp] = nil
      @exchange = exchange()
    end

    it 'should copy the export file to another location' do
      expect_log("Copied 1 file(s) from '#{@exchange.fullpath}' to '#{@options[:to]}'")

      @exchange.transfer

      File.read("#{@options[:to]}/dummy.csv").should == 'exported content'
    end
  end

  context 'ftp transfer' do
    before(:each) do
      @options[:to] = nil
      @exchange = exchange()
    end

    it 'should FTP the export file' do
      expect_log("Copied 1 file(s) from '#{@exchange.fullpath}' to '#{@options[:to_ftp]}/.'")

      ftp = double('Net::FTP')
      expect(ftp).to receive(:putbinaryfile).with(@exchange.fullpath, 'dummy.csv.in_progress')
      expect(ftp).to receive(:rename).with('dummy.csv.in_progress', 'dummy.csv')
      expect(Net::FTP).to receive(:open).with('ftp://ftp.example.com:888', 'ftp user', 'ftp password').and_yield(ftp)

      @exchange.transfer
    end

    it 'should use the to_ftp_dir option' do
      @exchange.options[:to_ftp_dir] = 'dir1/dir2'

      expect_log("Copied 1 file(s) from '#{@exchange.fullpath}' to '#{@options[:to_ftp]}/dir1/dir2'")

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