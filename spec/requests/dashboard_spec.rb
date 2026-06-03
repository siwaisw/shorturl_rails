require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  describe "GET /dashboard" do
    context "when not authenticated" do
      it "redirects to login" do
        get dashboard_path
        expect(response).to redirect_to(login_path)
      end
    end

    context "when authenticated" do
      before { post login_path, params: { email: user.email, password: "password123" } }

      it "returns 200" do
        get dashboard_path
        expect(response.status).to eq(200)
      end

      it "includes the user's short URLs" do
        create(:short_url, user: user, original_url: "https://example.com")
        get dashboard_path
        expect(response.body).to include("example.com")
      end

      it "excludes soft-deleted URLs" do
        create(:short_url, :soft_deleted, user: user, original_url: "https://deleted.example.com")
        get dashboard_path
        expect(response.body).not_to include("deleted.example.com")
      end
    end
  end

  describe "GET /dashboard/stats" do
    context "when not authenticated" do
      it "redirects to login" do
        get dashboard_stats_path
        expect(response).to redirect_to(login_path)
      end
    end

    context "when authenticated" do
      before do
        create(:short_url, user: user, click_count: 3)
        create(:short_url, user: user, click_count: 7)
        post login_path, params: { email: user.email, password: "password123" }
      end

      it "returns 200 with JSON" do
        get dashboard_stats_path
        expect(response.status).to eq(200)
        expect(response.content_type).to include("application/json")
      end

      it "returns total_clicks summed across all links" do
        get dashboard_stats_path
        body = JSON.parse(response.body)
        expect(body["total_clicks"]).to eq(10)
      end

      it "returns a links array with per-link click counts" do
        get dashboard_stats_path
        body = JSON.parse(response.body)
        expect(body["links"].map { |l| l["click_count"] }).to contain_exactly(3, 7)
      end

      it "excludes soft-deleted URLs from the totals" do
        create(:short_url, :soft_deleted, user: user, click_count: 99)
        get dashboard_stats_path
        body = JSON.parse(response.body)
        expect(body["total_clicks"]).to eq(10)
      end
    end
  end
end
