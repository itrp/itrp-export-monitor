require 'spec_helper'

describe Itrp::Export::Monitor::Service do
  before(:each) do
    # default configuration for testing
    Itrp::Export::Monitor.configure do |export|
      export.root = "#{@spec_dir}/tmp/exports"
      export.ids = [1, 2]
      export.to = "#{@spec_dir}/tmp/copy_to"

      export.to_ftp         = 'ftp://ftp.example.com:888'
      export.ftp_user_name  = 'ftp user'
      export.ftp_password   = 'ftp password'

      export.imap_address   = 'imap.example.com'
      export.imap_port      = 777
      export.imap_user_name = 'user@example.com'
      export.imap_password  = 'mail_password'
      export.imap_ssl       = true
      export.imap_mailbox   = 'Mail Inbox'
      export.imap_archive   = 'Mail Archive'
      export.imap_search    = 'My Search Query'
    end
  end

  context 'run' do
    it 'should use the singleton export monitor for both run and process' do
      Itrp::Export::Monitor::Service.any_instance.stub(:option){ 'v' }
      Itrp::Export::Monitor::Service.any_instance.stub(:generate_clacks_config){ 'clacks_config_file.rb' }
      command = double(exec: 'started')
      expect(Clacks::Command).to receive(:new).with(['-c', 'clacks_config_file.rb', '-D']) { command }

      service = Itrp::Export::Monitor.run

      expect(service).to receive(:process).with('mail')
      Itrp::Export::Monitor.process('mail')
    end
  end

  context 'initialize' do
    it 'should concatenate the :ids and :id options' do
      Itrp::Export::Monitor.configuration.id = 3
      monitor = Itrp::Export::Monitor::Service.new
      monitor.option(:ids).should == [1,2,3]
    end

    [:root, :ids, :imap_user_name, :imap_password].each do |required_option|
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

    [:csv_row_sep, :csv_col_sep, :csv_quote_char, :csv_value_proc].each do |unzip_dependent_option|
      it "should raise an exception is the option #{unzip_dependent_option} is set and unzip is false" do
        Itrp::Export::Monitor.configuration.unzip = false
        Itrp::Export::Monitor.configuration.send(:"#{unzip_dependent_option}=", unzip_dependent_option == :csv_value_proc ? Proc.new{|x| x} : 'not empty')
        expect{ Itrp::Export::Monitor::Service.new }.to raise_error(::Itrp::Exception, "Configuration option #{unzip_dependent_option} is only available when unzip is true")
      end
    end

    it 'should check the length of the csv_quote_char option' do
      Itrp::Export::Monitor.configuration.csv_quote_char = '7 chars'
      expect{ Itrp::Export::Monitor::Service.new }.to raise_error(::Itrp::Exception, 'Configuration option csv_quote_char must be 1 character long')
    end

    it 'should reset the idle timer on initialize' do
      Itrp::Export::Monitor::Service.any_instance.stub(:create_exit_when_idle_timer).and_raise('ok')
      expect{ Itrp::Export::Monitor::Service.new }.to raise_error('ok')
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

      @service = Itrp::Export::Monitor::Service.new
    end

    it 'should store export mails' do
      expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
      expect(@service).to receive(:store_export).with{ |export_mail| export_mail.original.should == @export_mail }

      @service.process(@export_mail)
    end

    it 'should reset the idle timer when a mail is processed' do
      expect(@service).to receive(:create_exit_when_idle_timer)
      @service.process(@export_mail)
    end

    it 'should skip mails when an exception occurs' do
      expect(@export_mail).to receive(:skip_deletion).once
      expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
      # raise exception with specific backtrace
      exception = Exception.new('oops!')
      allow(exception).to receive(:backtrace){ %w(trace back) }
      expect(@service).to receive(:store_export).and_raise(exception)
      # expect the error to be logged
      expect_log("Processing of mail 'Export finished - Full ad hoc export -- ITRP example' failed: oops!\n  trace\n  back", :error)

      @service.process(@export_mail)
    end

    it 'should not process a failed mail again' do
      # raise exception with specific backtrace
      exception = Exception.new('oops!')
      expect(@service).to receive(:store_export).once.and_raise(exception)

      @service.process(@export_mail)
      @service.process(@export_mail)
    end

    it 'should call the on_exception handler' do
      exception = Exception.new('oops!')
      exception_handler = Proc.new{}
      expect(exception_handler).to receive(:call).with(exception, kind_of(Itrp::Export::Monitor::Mail)).once

      Itrp::Export::Monitor.configuration.on_exception = exception_handler
      service = Itrp::Export::Monitor::Service.new
      expect(service).to receive(:store_export).and_raise(exception)

      service.process(@export_mail)
    end

    it 'should create a log entry when the on_exception handler fails' do
      exception = Exception.new('oops!')
      allow(exception).to receive(:backtrace){ %w(trace back) }
      another_exception = Exception.new('oops again!')
      allow(another_exception).to receive(:backtrace){ %w(trace back) }
      exception_handler = Proc.new{}
      expect(exception_handler).to receive(:call).with(exception, kind_of(Itrp::Export::Monitor::Mail)).and_raise(another_exception)

      Itrp::Export::Monitor.configuration.on_exception = exception_handler
      service = Itrp::Export::Monitor::Service.new
      expect(service).to receive(:store_export).and_raise(exception)

      expect_log("Processing ITRP Export mail:\n  Subject: Export finished - Full ad hoc export -- ITRP example\n  Export ID: 2\n  Token: #{@export_token}\n  URI: #{@export_uri}")
      expect_log("Processing of mail 'Export finished - Full ad hoc export -- ITRP example' failed: oops!\n  trace\n  back", :error)
      expect_log("Exception occurred in exception handling: oops again!\n  trace\n  back", :error)

      service.process(@export_mail)
    end

    it 'should skip non export mails' do
      expect(@non_export_mail).to receive(:skip_deletion).once
      expect_log("Skipping mail. Not an ITRP Export mail: \u00C4nderung #1687 Provide external hard disk drive -- ITRP example")

      @service.process(@non_export_mail)
    end

    it 'should not reset the idle timer when a non export mail is processed' do
      expect(@service).not_to receive(:create_exit_when_idle_timer)
      @service.process(@non_export_mail)
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
        Itrp::Export::Monitor::Exchange.any_instance.stub(:new){ double(transfer: 'transferring') }
        @service.process(@export_mail)

        File.read(@local_filename).should == 'exported content'
      end

      it 'should call the exchange handler' do
        expect(Itrp::Export::Monitor::Exchange).to receive(:new).with(@local_filename, @service.instance_variable_get(:@options)) { double(transfer: 'transferring') }
        @service.process(@export_mail)
      end

    end

  end

  context 'exit_when_idle' do

    it 'should not create an exit timer when the exit_when_idle option is -1' do
      Itrp::Export::Monitor.configuration.exit_when_idle = -1
      service = Itrp::Export::Monitor::Service.new
      service.instance_variable_get(:@exit_when_idle_timer).should == nil
    end

    it 'should stop the clacks service when the timeout is reached' do
      Itrp::Export::Monitor.configuration.exit_when_idle = 1

      Itrp::Export::Monitor::Service.any_instance.stub(:sleep).with(60)
      thread = double('thread')
      expect(Thread).to receive(:new).and_yield.and_return(thread)
      expect(Process).to receive(:pid){ 777 }
      expect(Process).to receive(:kill).with((Signal.list.keys & ['QUIT', 'INT']).first, 777)

      service = Itrp::Export::Monitor::Service.new
      service.instance_variable_get(:@exit_when_idle_timer).should == thread
    end

    it 'should log an error when the timer could not be created' do
      Itrp::Export::Monitor.configuration.exit_when_idle = 1

      exception = Exception.new('oops!')
      allow(exception).to receive(:backtrace){ %w(trace back) }
      expect(Thread).to receive(:new).and_raise(exception)
      # expect the error to be logged
      expect_log("Unable to schedule timer to exit when idle in 60 seconds: oops!\n  trace\n  back", :error)

      service = Itrp::Export::Monitor::Service.new
    end
  end

  it 'should create a clacks config file' do
    clacks_filename = Itrp::Export::Monitor::Service.new.generate_clacks_config
    clacks_config = File.read(clacks_filename)

    clacks_config.should == <<OEF
# -- DO NOT EDIT --
# Generated by the Export Monitor

pid "#{@spec_dir}/tmp/exports/pids/export_monitor.1.2.pid"
stdout_path "#{@spec_dir}/log/test.log"
stderr_path "#{@spec_dir}/log/test.log"

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
  keys:              'My Search Query',
  delete_after_find: true # Note that only the processed export mails will be deleted
})

on_mail do |mail|
  Itrp::Export::Monitor.process(mail)
end
OEF
  end

end
