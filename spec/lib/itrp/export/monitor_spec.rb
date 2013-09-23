require 'spec_helper'

describe Itrp::Export::Monitor do
  it 'should define a default configuration' do
    conf = Itrp::Export::Monitor.configuration.current

    conf.keys.sort.should == [:daemonize, :ftp_password, :ftp_user_name, :id, :ids, :imap_address, :imap_archive, :imap_mailbox, :imap_password, :imap_port, :imap_ssl, :imap_user_name, :logger, :on_exception, :root, :to, :to_ftp, :to_ftp_dir]

    conf[:logger].class.should == ::Logger
    conf[:daemonize].should == false
    conf[:imap_address].should == 'imap.googlemail.com'
    conf[:imap_port].should == 993
    conf[:imap_ssl].should == true
    conf[:imap_mailbox].should == 'INBOX'
    conf[:imap_archive].should == '[Gmail]/All Mail'
    conf[:to_ftp_dir].should == '.'

    [:ftp_password, :ftp_user_name, :id, :ids, :imap_password, :imap_user_name, :name, :root, :to, :to_ftp].each do |no_default|
      conf[no_default].should == nil
    end
  end

  it 'should define a logger' do
    Itrp::Export::Monitor.logger.class.should == ::Logger
  end

end