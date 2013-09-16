require 'spec_helper'

describe Itrp::Export::Monitor::Service do
  before(:each) do
    # default configuration for testing
    Itrp::Export::Monitor.configure do |export|
      export.root = "#{@spec_dir}/tmp/exports"
      export.ids = [1, 2]
      export.name = "export.1.2"
      export.to = "#{@spec_dir}/tmp/copy_to"

      export.to_ftp =        'ftp://ftp.example.com:888'
      export.ftp_user_name = 'ftp user'
      export.ftp_password =  'ftp password'

      export.imap_address =    'imap.example.com'
      export.imap_port =       777
      export.imap_user_name =  'user@example.com'
      export.imap_password =   'mail_password'
      export.imap_ssl =         true
      export.imap_mailbox =    'Mail Inbox'
      export.imap_archive =    'Mail Archive'
    end
  end

  context 'run' do
    it 'should use the singleton export monitor for both run and process' do
      Itrp::Export::Monitor::Service.any_instance.stub(:option){ 'value' }
      Itrp::Export::Monitor::Service.any_instance.stub(:generate_clacks_config){ 'clacks_config_file.rb' }
      expect(Clacks::Command).to receive(:new).with(['-c', 'clacks_config_file.rb', '-D']) { double(exec: 'started') }

      monitor = Itrp::Export::Monitor::Service.run

      expect(monitor).to receive(:process).with('mail')
      Itrp::Export::Monitor::Service.process('mail')
    end

  end

  context 'initialize' do
    it 'should concatenate the :ids and :id options' do
      Itrp::Export::Monitor.configuration.id = 3
      monitor = Itrp::Export::Monitor::Service.new
      monitor.option(:ids).should == [1,2,3]
    end

    [:name, :root, :ids, :imap_user_name, :imap_password].each do |required_option|
      it "should raise an exception is the required option #{required_option} is missing" do
        Itrp::Export::Monitor.configuration.send(:"#{required_option}=", required_option == :ids ? [] : '')
        expect{ Itrp::Export::Monitor::Service.new }.to raise_error(::Itrp::Exception, "Missing required configuration option #{required_option}")
      end
    end

    it 'should set the logger' do
      logger = Logger.new($stdout)
      Itrp::Export::Monitor.configuration.logger = logger
      monitor = Itrp::Export::Monitor::Service.new
      monitor.instance_variable_get(:@logger).should == logger
    end
  end

  it 'should define the option method' do
    monitor = Itrp::Export::Monitor::Service.new
    monitor.option(:ids).should == [1,2]
    monitor.option(:imap_address).should == 'imap.example.com'
    monitor.option(:imap_port).should == 777
  end

  context 'process' do
    before(:each) do
      @export_uri = 'https://itrp.amazonaws.com/exports/20130911/wdc/20130911-195545-affected_slas.csv?AWSAccessKeyId=AKIA&Signature=du%2B23ZUsrLng%3D&Expires=1379102146'
      @export_token = '0fad4fc0fd4a0130ad2a12313b0e50759969ab71899d2bb1d3e3d8f66e6e5133'

      @export_mail = ::Mail.new(File.read("#{@fixture_dir}/export_finished_1.eml"))
      @non_export_mail = ::Mail.new(File.read("#{@fixture_dir}/non_export.eml"))

      @monitor = Itrp::Export::Monitor::Service.new
    end

    it 'should store export mails' do
      expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
      expect(@monitor).to receive(:store_export).with{ |export_mail| export_mail.original.should == @export_mail }

      @monitor.process(@export_mail)
    end

    it 'should skip mails when an exception occurs' do
      expect(@export_mail).to receive(:skip_deletion).once
      expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
      # raise exception with specific backtrace
      exception = Exception.new('oops!')
      allow(exception).to receive(:backtrace){ ['trace', 'back'] }
      expect(@monitor).to receive(:store_export).and_raise(exception)
      # expect the error to be logged
      expect_log("Processing failed: oops!\n  trace\n  back", :error)

      @monitor.process(@export_mail)
    end

    it 'should skip non export mails' do
      expect(@non_export_mail).to receive(:skip_deletion).once
      expect_log("Skipping mail. Not an ITRP Export mail: \u00C4nderung #1687 Provide external hard disk drive -- ITRP example")

      @monitor.process(@non_export_mail)
    end

    it 'should skip non-monitored export ids' do
      Itrp::Export::Monitor.configuration.ids = [1,3]
      monitor = Itrp::Export::Monitor::Service.new

      expect(@export_mail).to receive(:skip_deletion).once
      expect_log('Skipping mail. ITRP Export ID 2 not configured for monitoring')

      monitor.process(@export_mail)
    end

    context 'store_export' do
      before(:each) do
        stub_request(:get, @export_uri).to_return(body: 'exported content')
        @local_filename = "#{Itrp::Export::Monitor.configuration.root}/downloads/20130911-195545-affected_slas.csv"
      end

      it 'should download the export file to disk' do
        expect(@monitor).to receive(:copy_export)
        expect(@monitor).to receive(:ftp_export)
        @monitor.process(@export_mail)

        File.read(@local_filename).should == 'exported content'
      end

      it 'should copy the export file to another location' do
        expect(@monitor).to receive(:ftp_export)
        expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
        expect_log("Copied export '#{@local_filename}' to '#{Itrp::Export::Monitor.configuration.to}/20130911-195545-affected_slas.csv'")

        @monitor.process(@export_mail)

        File.read(@local_filename).should == 'exported content'
        File.read("#{Itrp::Export::Monitor.configuration.to}/20130911-195545-affected_slas.csv").should == 'exported content'
      end

      it 'should FTP the export file' do
        expect(@monitor).to receive(:copy_export)
        expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
        expect_log("FTP export '#{@local_filename}' to '#{Itrp::Export::Monitor.configuration.to_ftp}/20130911-195545-affected_slas.csv'")

        ftp = double('Net::FTP')
        expect(ftp).to receive(:putbinaryfile).with(@local_filename, '20130911-195545-affected_slas.csv.in_progress')
        expect(ftp).to receive(:rename).with('20130911-195545-affected_slas.csv.in_progress', '20130911-195545-affected_slas.csv')
        expect(Net::FTP).to receive(:open).with('ftp://ftp.example.com:888', 'ftp user', 'ftp password').and_yield(ftp)

        @monitor.process(@export_mail)

        File.read(@local_filename).should == 'exported content'
      end
    end

  end

  it 'should create a clacks config file' do
    clacks_filename = Itrp::Export::Monitor::Service.new.generate_clacks_config
    clacks_config = File.read(clacks_filename)

    clacks_config.should == <<OEF
# -- DO NOT EDIT --
# Generated by the Export Monitor

pid "/home/mathijs/dev/itrp-export-monitor/spec/tmp/exports/pids/export_monitor.1.2.pid"
stdout_path "/home/mathijs/dev/itrp-export-monitor/spec/tmp/exports/log/export_monitor.1.2.log"
stderr_path "/home/mathijs/dev/itrp-export-monitor/spec/tmp/exports/log/export_monitor.1.2.log"

imap({
  address:    'imap.example.com',
  port:       777,
  user_name:  'user@example.com',
  password:   'mail_password',
  enable_ssl: true
})

find_options({
  mailbox:           'Mail Inbox',
  archivebox:        'Mail Archive',
  keys:              'FROM ITRP HEADER X-ITRP-ExportID ""',
  delete_after_find: true # Note that only the processed export mails will be deleted
})

on_mail do |mail|
  Itrp::Export::Monitor::Service.process(mail)
end
OEF
  end
end
