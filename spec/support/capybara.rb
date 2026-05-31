require "capybara/rspec"

RSpec.configure do |config|
  # Default: rack_test (fast, no browser process, works with transactional fixtures)
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # JS tests use headless Chrome. These require DatabaseCleaner because Selenium
  # runs in a separate thread and cannot see data wrapped in a test transaction.
  # See spec/support/database_cleaner.rb (add when you need js: true specs).
  config.before(:each, type: :system, js: true) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900]
  end
end
