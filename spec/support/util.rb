def expect_log(text, level = :info, logger = Sdk4me.configuration.logger)
  expect(logger).to(receive(level).ordered { |&args| expect(args.call).to eq(text) })
end
