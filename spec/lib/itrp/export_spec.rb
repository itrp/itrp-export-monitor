require 'spec_helper'

describe Itrp::Export do
  it "should define a default configuration" do
    conf = Itrp::Export.configuration.current

    conf.keys.sort.should == [:daemon, :ftp_password, :ftp_user_name, :id, :ids, :imap_address, :imap_archive, :imap_mailbox, :imap_password, :imap_port, :imap_ssl, :imap_user_name, :logger, :name, :root, :to, :to_ftp]

    conf[:logger].class.should == ::Logger
    conf[:daemon].should == false
    conf[:imap_address].should == 'imap.googlemail.com'
    conf[:imap_port].should == 993
    conf[:imap_ssl].should == true
    conf[:imap_mailbox].should == 'INBOX'
    conf[:imap_archive].should == '[Gmail]/All Mail'

    [:ftp_password, :ftp_user_name, :id, :ids, :imap_password, :imap_user_name, :name, :root, :to, :to_ftp].each do |no_default|
      conf[no_default].should == nil
    end
  end

  it "should define a logger" do
    Itrp::Export.logger.class.should == ::Logger
  end
end