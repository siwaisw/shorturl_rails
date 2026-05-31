require "database_cleaner/active_record"

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    # JS system specs run in a separate Selenium thread — truncation commits data
    # to the DB so the server thread can see it. Everything else uses transactions
    # (faster, auto-rolled-back after each example).
    strategy = example.metadata[:js] ? :truncation : :transaction
    DatabaseCleaner.strategy = strategy
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
