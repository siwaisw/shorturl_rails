require "rails_helper"

RSpec.describe "Dashboard", type: :system do
  let(:user) { create(:user) }
  let!(:active_url) do
    create(:short_url, user: user, click_count: 5, expires_at: 1.year.from_now)
  end
  let!(:expired_url) do
    create(:short_url, :expired, user: user, click_count: 2)
  end

  before { sign_in_as(user) }

  describe "stat cards" do
    before { visit dashboard_path }

    it "shows total link count" do
      within(".stat-card", text: "Total links") do
        expect(page).to have_css(".stat-card-value", text: "2")
      end
    end

    it "shows total click count" do
      # active (5) + expired (2) = 7
      expect(page).to have_css("[data-clicks-target='total']", text: "7")
    end

    it "shows active link count" do
      within(".stat-card", text: "Active links") do
        expect(page).to have_css(".stat-card-value", text: "1")
      end
    end
  end

  describe "links table" do
    before { visit dashboard_path }

    it "shows a row for each link" do
      expect(page).to have_css(".urls-table tbody tr", count: 2)
    end

    it "shows the click count for each link" do
      expect(page).to have_css("[data-clicks-target='linkCount']", text: "5")
      expect(page).to have_css("[data-clicks-target='linkCount']", text: "2")
    end

    it "shows an active badge for non-expired links" do
      expect(page).to have_css(".badge-active", text: "Active")
    end

    it "shows an expired badge for expired links" do
      expect(page).to have_css(".badge-expired", text: "Expired")
    end

    it "links to the short URL" do
      expect(page).to have_link(href: short_url_redirect_path(active_url.short_key))
    end
  end

  describe "shorten form" do
    it "creates a new short link and shows the result" do
      visit dashboard_path
      fill_in "short_url[original_url]", with: "https://example.com/some/long/path"
      click_button "Shorten URL"

      expect(page).to have_text("Your short link is ready!")
    end

    it "shows an error for an invalid URL" do
      visit dashboard_path
      # rack_test bypasses browser-native URL validation so we can submit directly
      fill_in "short_url[original_url]", with: "not-a-url"
      click_button "Shorten URL"

      expect(page).to have_text("must be a valid HTTP or HTTPS URL")
    end
  end

  describe "authentication guard" do
    it "redirects to login when not signed in" do
      # Visit without signing in
      Capybara.reset_sessions!
      visit dashboard_path
      expect(page).to have_current_path(login_path)
    end
  end

  describe "click count auto-update", js: true do
    it "updates the per-link count within 5 seconds of a redirect" do
      visit dashboard_path
      expect(page).to have_css("[data-clicks-target='linkCount'][data-id='#{active_url.id}']",
                               text: "5")

      page.execute_script("fetch('/#{active_url.short_key}')")

      expect(page).to have_css("[data-clicks-target='linkCount'][data-id='#{active_url.id}']",
                               text: "6", wait: 10)
    end

    it "updates the total clicks count within 5 seconds of a redirect" do
      visit dashboard_path
      expect(page).to have_css("[data-clicks-target='total']", text: "7")

      page.execute_script("fetch('/#{active_url.short_key}')")

      expect(page).to have_css("[data-clicks-target='total']", text: "8", wait: 10)
    end
  end
end
