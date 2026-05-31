require "capybara/rspec"

RSpec.configure do |config|
  # Default: rack_test (fast, no browser process, works with transactional fixtures)
  config.before(:each, type: :system) do
    driven_by :rack_test
  end
  # Use Selenium with headless Chrome for JS-enabled tests (slower, requires browser process, cannot use transactional fixtures).
  # See spec/support/database_cleaner.rb (add when you need js: true specs).
  config.before(:each, type: :system, js: true) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]
  end
end
