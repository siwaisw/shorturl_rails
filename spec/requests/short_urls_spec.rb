require "rails_helper"

RSpec.describe "ShortUrls", type: :request do
  describe "POST /short_urls" do
    context "with a valid HTTPS URL" do
      let(:valid_params) { { short_url: { original_url: "https://chicken-nuggets.com/some/path" } } }

      it "redirects to the root path" do
        post short_urls_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "creates a new ShortUrl record" do
        expect {
          post short_urls_path, params: valid_params
        }.to change(ShortUrl, :count).by(1)
      end

      it "sets flash[:short_url] to a URL ending with the generated short key" do
        post short_urls_path, params: valid_params
        expect(flash[:short_url]).to end_with("/#{ShortUrl.last.short_key}")
      end

      it "includes the request host in flash[:short_url]" do
        post short_urls_path, params: valid_params
        expect(flash[:short_url]).to start_with("http://")
      end
    end

    context "with a valid HTTP URL" do
      it "creates a record" do
        expect {
          post short_urls_path, params: { short_url: { original_url: "http://chicken-nuggets.com" } }
        }.to change(ShortUrl, :count).by(1)
      end
    end

    context "with a blank URL" do
      let(:blank_params) { { short_url: { original_url: "" } } }

      it "redirects to the root path" do
        post short_urls_path, params: blank_params
        expect(response).to redirect_to(root_path)
      end

      it "does not create a record" do
        expect {
          post short_urls_path, params: blank_params
        }.not_to change(ShortUrl, :count)
      end

      it "sets flash[:alert]" do
        post short_urls_path, params: blank_params
        expect(flash[:alert]).to be_present
      end
    end

    context "with a non-HTTP/HTTPS URL" do
      let(:ftp_params) { { short_url: { original_url: "ftp://chicken-nugget-files.example.com" } } }

      it "redirects to the root path" do
        post short_urls_path, params: ftp_params
        expect(response).to redirect_to(root_path)
      end

      it "does not create a record" do
        expect {
          post short_urls_path, params: ftp_params
        }.not_to change(ShortUrl, :count)
      end

      it "sets flash[:alert] mentioning a valid HTTP or HTTPS URL" do
        post short_urls_path, params: ftp_params
        expect(flash[:alert]).to include("valid HTTP or HTTPS")
      end
    end

    context "with a bare string that is not a URL" do
      it "does not create a record" do
        expect {
          post short_urls_path, params: { short_url: { original_url: "not-a-nugget" } }
        }.not_to change(ShortUrl, :count)
      end
    end

    context "guest daily limit" do
      let(:valid_params) { { short_url: { original_url: "https://chicken-nuggets.com/path" } } }
      let(:cache_key) { "url_guest_limit:#{Time.zone.today}:127.0.0.1" }
      let(:cache) { ActiveSupport::Cache::MemoryStore.new }

      before { allow(Rails).to receive(:cache).and_return(cache) }

      it "allows creation when under the daily limit" do
        cache.write(cache_key, ShortUrlsController::GUEST_DAILY_LIMIT - 1)
        expect {
          post short_urls_path, params: valid_params
        }.to change(ShortUrl, :count).by(1)
      end

      it "blocks creation when the daily limit is already reached" do
        cache.write(cache_key, ShortUrlsController::GUEST_DAILY_LIMIT)
        expect {
          post short_urls_path, params: valid_params
        }.not_to change(ShortUrl, :count)
      end

      it "sets flash[:alert] when the limit is reached" do
        cache.write(cache_key, ShortUrlsController::GUEST_DAILY_LIMIT)
        post short_urls_path, params: valid_params
        expect(flash[:alert]).to include("Daily link limit reached")
      end

      it "redirects to root when the limit is reached" do
        cache.write(cache_key, ShortUrlsController::GUEST_DAILY_LIMIT)
        post short_urls_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "does not increment the counter when URL validation fails" do
        cache.write(cache_key, 0)
        post short_urls_path, params: { short_url: { original_url: "not-a-url" } }
        expect(cache.read(cache_key)).to eq(0)
      end

      it "increments the counter only after a successful save" do
        cache.write(cache_key, ShortUrlsController::GUEST_DAILY_LIMIT - 1)
        post short_urls_path, params: valid_params
        expect(cache.read(cache_key)).to eq(ShortUrlsController::GUEST_DAILY_LIMIT)
      end
    end

    context "user url_limit" do
      let(:valid_params) { { short_url: { original_url: "https://chicken-nuggets.com/path" } } }

      context "when the user has no limit set" do
        let(:user) { create(:user, url_limit: nil) }

        before { post login_path, params: { email: user.email, password: "password123" } }

        it "allows creation without restriction" do
          expect {
            post short_urls_path, params: valid_params
          }.to change(ShortUrl, :count).by(1)
        end
      end

      context "when the user is under their limit" do
        let(:user) { create(:user, url_limit: 3) }

        before do
          create_list(:short_url, 2, user: user)
          post login_path, params: { email: user.email, password: "password123" }
        end

        it "allows creation" do
          expect {
            post short_urls_path, params: valid_params
          }.to change(ShortUrl, :count).by(1)
        end
      end

      context "when the user has reached their limit" do
        let(:user) { create(:user, url_limit: 2) }

        before do
          create_list(:short_url, 2, user: user)
          post login_path, params: { email: user.email, password: "password123" }
        end

        it "does not create a record" do
          expect {
            post short_urls_path, params: valid_params
          }.not_to change(ShortUrl, :count)
        end

        it "sets flash[:alert] mentioning the limit" do
          post short_urls_path, params: valid_params
          expect(flash[:alert]).to include("link limit of 2")
        end

        it "redirects to root" do
          post short_urls_path, params: valid_params
          expect(response).to redirect_to(root_path)
        end
      end

      context "when soft-deleted URLs would push the count over the limit" do
        let(:user) { create(:user, url_limit: 2) }

        before do
          create_list(:short_url, 2, user: user).each(&:soft_delete!)
          post login_path, params: { email: user.email, password: "password123" }
        end

        it "allows creation because soft-deleted records are excluded from the quota" do
          expect {
            post short_urls_path, params: valid_params
          }.to change(ShortUrl, :count).by(1)
        end
      end
    end
  end

  describe "GET /:key" do
    context "with a valid, non-expired key" do
      let!(:short_url) { create(:short_url, original_url: "https://destination-nugget.example.com") }

      it "redirects to the original URL" do
        get "/#{short_url.short_key}"
        expect(response).to redirect_to("https://destination-nugget.example.com")
      end

      it "responds with a 301 Moved Permanently status" do
        get "/#{short_url.short_key}"
        expect(response.status).to eq(301)
      end

      it "increments the click count by 1" do
        expect {
          get "/#{short_url.short_key}"
        }.to change { short_url.reload.click_count }.by(1)
      end
    end

    context "with an expired key" do
      let!(:expired_url) { create(:short_url, :expired) }

      it "redirects to the root path" do
        get "/#{expired_url.short_key}"
        expect(response).to redirect_to(root_path)
      end

      it "sets flash[:alert]" do
        get "/#{expired_url.short_key}"
        expect(flash[:alert]).to be_present
      end

      it "does not increment the click count" do
        expect {
          get "/#{expired_url.short_key}"
        }.not_to change { expired_url.reload.click_count }
      end
    end

    context "with an unknown key" do
      it "returns 404" do
        get "/zzzzzzz"
        expect(response.status).to eq(404)
      end
    end
  end
end
