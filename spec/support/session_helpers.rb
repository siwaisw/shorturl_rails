module SessionHelpers
  def sign_in_as(user, password: "password123")
    visit login_path
    fill_in "Email address", with: user.email
    fill_in "Password",       with: password
    click_button "Log in"
  end
end

RSpec.configure do |config|
  config.include SessionHelpers, type: :system
end
