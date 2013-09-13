require 'spec_helper'

describe Itrp::Export::Mail do
  before(:each) do
    @export_mail = Itrp::Export::Mail.new(::Mail.new(File.read("#{@fixture_dir}/export_finished_1.eml")))
    @non_export_mail = Itrp::Export::Mail.new(::Mail.new(File.read("#{@fixture_dir}/non_export.eml")))
  end

  context 'exportID' do
    it 'should retrieve the id for export mails' do
      @export_mail.export_id.should == 2
    end

    it 'should return nil for non export mails' do
      @non_export_mail.export_id.should == nil
    end
  end

  context 'token' do
    it 'should retrieve the token for export mails' do
      @export_mail.token.should == '0fad4fc0fd4a0130ad2a12313b0e50759969ab71899d2bb1d3e3d8f66e6e5133'
    end

    it 'should return nil for non export mails' do
      @non_export_mail.token.should == nil
    end
  end

  context 'download_uri' do
    it 'should retrieve the uri for export mails' do
      @export_mail.download_uri.should == 'https://itrp.amazonaws.com/exports/20130911/wdc/20130911-195545-affected_slas.csv?AWSAccessKeyId=AKIA&Signature=du%2B23ZUsrLng%3D&Expires=1379102146'
    end

    it 'should return nil for non export mails' do
      @non_export_mail.download_uri.should == nil
    end
  end

  context 'filename' do
    it 'should retrieve the filename for export mails' do
      @export_mail.filename.should == '20130911-195545-affected_slas.csv'
    end

    it 'should return nil for non export mails' do
      @non_export_mail.download_uri.should == nil
    end
  end

  it 'should set skip deletion on the mail when ignore is called' do
    expect(@export_mail.original).to receive(:skip_deletion).once

    @export_mail.ignore
  end

end
