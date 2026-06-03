require "rails_helper"

RSpec.describe "Api::V1::Urls", type: :request do
  let(:user)         { create(:user) }
  let(:other_user)   { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{user.api_key}" } }

  def json_body
    JSON.parse(response.body)
  end

  describe "Authentication" do
    it "returns 401 when the Authorization header is absent" do
      get "/api/v1/urls/0000001"
      expect(response.status).to eq(401)
      expect(json_body.dig("error", "code")).to eq("unauthorized")
    end

    it "returns 401 when the token does not match any user" do
      get "/api/v1/urls/0000001", headers: { "Authorization" => "Bearer invalid_token" }
      expect(response.status).to eq(401)
    end
  end

  describe "POST /api/v1/urls" do
    context "with a valid URL" do
      let(:params) { { url: "https://example.com/long/path" } }

      it "returns 201 Created" do
        post "/api/v1/urls", params: params, headers: auth_headers
        expect(response.status).to eq(201)
      end

      it "creates a new ShortUrl record belonging to the API user" do
        expect {
          post "/api/v1/urls", params: params, headers: auth_headers
        }.to change { user.short_urls.count }.by(1)
      end

      it "returns the expected JSON shape" do
        post "/api/v1/urls", params: params, headers: auth_headers
        expect(json_body).to include(
          "short_key"    => be_a(String),
          "short_url"    => include("/"),
          "original_url" => "https://example.com/long/path",
          "click_count"  => 0
        )
        expect(json_body["expires_at"]).to be_present
        expect(json_body["created_at"]).to be_present
      end

      it "defaults expires_at to approximately 1 year from now" do
        post "/api/v1/urls", params: params, headers: auth_headers
        expires_at = Time.zone.parse(json_body["expires_at"])
        expect(expires_at).to be_within(1.minute).of(1.year.from_now)
      end
    end

    context "with a custom expires_at" do
      it "uses the provided expires_at" do
        future = 6.months.from_now.iso8601
        post "/api/v1/urls",
             params: { url: "https://example.com", expires_at: future },
             headers: auth_headers
        expect(response.status).to eq(201)
        expect(Time.zone.parse(json_body["expires_at"])).to be_within(1.second).of(6.months.from_now)
      end

      it "returns 422 for an invalid datetime string" do
        post "/api/v1/urls",
             params: { url: "https://example.com", expires_at: "not-a-date" },
             headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("validation_error")
      end
    end

    context "with a missing url" do
      it "returns 422 validation_error" do
        post "/api/v1/urls", params: {}, headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("validation_error")
      end
    end

    context "with a non-HTTP/HTTPS url" do
      it "returns 422 invalid_url" do
        post "/api/v1/urls",
             params: { url: "ftp://example.com" },
             headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("invalid_url")
      end
    end

    context "with a plain string that is not a URL" do
      it "returns 422 invalid_url" do
        post "/api/v1/urls",
             params: { url: "not-a-url" },
             headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("invalid_url")
      end
    end

    context "when the user has reached their url_limit" do
      before { user.update!(url_limit: 1) }

      it "returns 422 quota_exceeded when the limit is already reached" do
        create(:short_url, user: user)
        post "/api/v1/urls", params: { url: "https://example.com" }, headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("quota_exceeded")
      end

      it "allows creation when still under the limit" do
        post "/api/v1/urls", params: { url: "https://example.com" }, headers: auth_headers
        expect(response.status).to eq(201)
      end

      it "excludes soft-deleted URLs from the quota count" do
        create(:short_url, :soft_deleted, user: user)
        post "/api/v1/urls", params: { url: "https://example.com" }, headers: auth_headers
        expect(response.status).to eq(201)
      end
    end
  end

  describe "GET /api/v1/urls/:key" do
    let!(:short_url) { create(:short_url, user: user) }

    context "for the authenticated user's own URL" do
      it "returns 200 with the URL details" do
        get "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
        expect(response.status).to eq(200)
        expect(json_body["short_key"]).to eq(short_url.short_key)
        expect(json_body["original_url"]).to eq(short_url.original_url)
        expect(json_body["click_count"]).to eq(0)
      end
    end

    context "for another user's URL" do
      let!(:other_url) { create(:short_url, user: other_user) }

      it "returns 404 not_found" do
        get "/api/v1/urls/#{other_url.short_key}", headers: auth_headers
        expect(response.status).to eq(404)
        expect(json_body.dig("error", "code")).to eq("not_found")
      end
    end

    context "for a non-existent key" do
      it "returns 404 not_found" do
        get "/api/v1/urls/zzzzzzz", headers: auth_headers
        expect(response.status).to eq(404)
      end
    end

    context "for an expired URL" do
      let!(:expired_url) { create(:short_url, :expired, user: user) }

      it "returns 200 — expired URLs are still visible for analytics" do
        get "/api/v1/urls/#{expired_url.short_key}", headers: auth_headers
        expect(response.status).to eq(200)
      end
    end

    context "for a soft-deleted URL" do
      let!(:deleted_url) { create(:short_url, :soft_deleted, user: user) }

      it "returns 404 — soft-deleted URLs are treated as gone" do
        get "/api/v1/urls/#{deleted_url.short_key}", headers: auth_headers
        expect(response.status).to eq(404)
      end
    end
  end

  describe "PATCH /api/v1/urls/:key" do
    let!(:short_url) { create(:short_url, user: user) }
    let(:future_ts)  { 2.years.from_now.iso8601 }

    context "with a valid future expires_at" do
      it "returns 200 with the updated resource" do
        patch "/api/v1/urls/#{short_url.short_key}",
              params: { expires_at: future_ts },
              headers: auth_headers
        expect(response.status).to eq(200)
        expect(Time.zone.parse(json_body["expires_at"])).to be_within(1.second).of(2.years.from_now)
      end

      it "persists the new expiry to the database" do
        patch "/api/v1/urls/#{short_url.short_key}",
              params: { expires_at: future_ts },
              headers: auth_headers
        expect(short_url.reload.expires_at).to be_within(1.second).of(2.years.from_now)
      end
    end

    context "with a missing expires_at" do
      it "returns 422 validation_error" do
        patch "/api/v1/urls/#{short_url.short_key}", params: {}, headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("validation_error")
      end
    end

    context "with an invalid datetime string" do
      it "returns 422 validation_error" do
        patch "/api/v1/urls/#{short_url.short_key}",
              params: { expires_at: "not-a-date" },
              headers: auth_headers
        expect(response.status).to eq(422)
      end
    end

    context "with a past expires_at" do
      it "returns 422 validation_error" do
        patch "/api/v1/urls/#{short_url.short_key}",
              params: { expires_at: 1.day.ago.iso8601 },
              headers: auth_headers
        expect(response.status).to eq(422)
        expect(json_body.dig("error", "code")).to eq("validation_error")
      end
    end

    context "for another user's URL" do
      let!(:other_url) { create(:short_url, user: other_user) }

      it "returns 404" do
        patch "/api/v1/urls/#{other_url.short_key}",
              params: { expires_at: future_ts },
              headers: auth_headers
        expect(response.status).to eq(404)
      end
    end
  end

  describe "DELETE /api/v1/urls/:key" do
    let!(:short_url) { create(:short_url, user: user) }

    context "for the authenticated user's own URL" do
      it "returns 204 No Content" do
        delete "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
        expect(response.status).to eq(204)
        expect(response.body).to be_empty
      end

      it "soft-deletes the URL (sets deleted_at)" do
        delete "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
        expect(short_url.reload.deleted_at).not_to be_nil
      end

      it "does not hard-delete the record from the database" do
        delete "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
        expect(ShortUrl.unscoped.exists?(short_url.id)).to be true
      end
    end

    context "for another user's URL" do
      let!(:other_url) { create(:short_url, user: other_user) }

      it "returns 404 and does not delete" do
        delete "/api/v1/urls/#{other_url.short_key}", headers: auth_headers
        expect(response.status).to eq(404)
        expect(other_url.reload.deleted_at).to be_nil
      end
    end

    context "for a non-existent key" do
      it "returns 404" do
        delete "/api/v1/urls/zzzzzzz", headers: auth_headers
        expect(response.status).to eq(404)
      end
    end
  end

  describe "Rate limiting" do
    let!(:short_url) { create(:short_url, user: user) }

    it "includes X-RateLimit headers on every response" do
      get "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
      expect(response.headers["X-RateLimit-Limit"]).to     eq("100")
      expect(response.headers["X-RateLimit-Remaining"]).to be_present
      expect(response.headers["X-RateLimit-Reset"]).to     be_present
    end

    context "when the rate limit is exceeded" do
      before { allow(Rails.cache).to receive(:increment).and_return(101) }

      it "returns 429 Too Many Requests" do
        get "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
        expect(response.status).to eq(429)
        expect(json_body.dig("error", "code")).to eq("rate_limit_exceeded")
      end

      it "includes the Retry-After header" do
        get "/api/v1/urls/#{short_url.short_key}", headers: auth_headers
        expect(response.headers["Retry-After"]).to be_present
      end
    end
  end
end
