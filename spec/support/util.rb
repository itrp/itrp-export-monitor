def expect_log(text, level = :info, logger = Itrp::Export::Monitor.configuration.logger)
  expect(logger).to receive(level).ordered { |&args| (args.call).should == text }
end