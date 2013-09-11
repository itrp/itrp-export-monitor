require 'spec_helper'

describe Itrp::Export::Monitor do
  it 'should use the singleton export monitor for both run and process' do
    Itrp::Export::Monitor.any_instance.stub(:option){ 'value' }
    monitor = Itrp::Export::Monitor.run

    expect(monitor).to receive(:process).with('mail')
    Itrp::Export::Monitor.process('mail')
  end
end
