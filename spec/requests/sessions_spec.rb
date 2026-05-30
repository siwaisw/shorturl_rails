require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user, email: "tester@example.com",
                               password: "password123",
                               password_confirmation: "password123") }

  # ── GET /login ─────────────────────────────────────────────
  describe "GET /login" do
    context "when not logged in" do
      it "returns 200" do
        get login_path
        expect(response.status).to eq(200)
      end
    end

    context "when already logged in" do
      before { post login_path, params: { email: user.email, password: "password123" } }

      it "redirects to the dashboard" do
        get login_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  # ── POST /login ────────────────────────────────────────────
  describe "POST /login" do
    context "with correct credentials" do
      it "sets session[:user_id] to the authenticated user's id" do
        post login_path, params: { email: "tester@example.com", password: "password123" }
        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to the dashboard" do
        post login_path, params: { email: "tester@example.com", password: "password123" }
        expect(response).to redirect_to(dashboard_path)
      end

      it "sets a welcome flash notice" do
        post login_path, params: { email: "tester@example.com", password: "password123" }
        expect(flash[:notice]).to be_present
      end

      it "matches the email case-insensitively" do
        post login_path, params: { email: "TESTER@EXAMPLE.COM", password: "password123" }
        expect(session[:user_id]).to eq(user.id)
      end

      it "matches even with surrounding whitespace in the email" do
        post login_path, params: { email: "  tester@example.com  ", password: "password123" }
        expect(session[:user_id]).to eq(user.id)
      end
    end

    context "with a wrong password" do
      before { post login_path, params: { email: "tester@example.com", password: "wrongpassword" } }

      it "does not set session[:user_id]" do
        expect(session[:user_id]).to be_nil
      end

      it "responds with 422 Unprocessable Entity" do
        expect(response.status).to eq(422)
      end

      it "sets flash[:alert] with an error message" do
        expect(flash[:alert]).to be_present
      end
    end

    context "with an unknown email address" do
      before { post login_path, params: { email: "nobody@example.com", password: "password123" } }

      it "does not set session[:user_id]" do
        expect(session[:user_id]).to be_nil
      end

      it "responds with 422" do
        expect(response.status).to eq(422)
      end

      it "sets flash[:alert]" do
        expect(flash[:alert]).to be_present
      end
    end

    context "with a blank password" do
      it "does not authenticate" do
        post login_path, params: { email: "tester@example.com", password: "" }
        expect(session[:user_id]).to be_nil
      end
    end
  end

  # ── DELETE /logout ─────────────────────────────────────────
  describe "DELETE /logout" do
    before { post login_path, params: { email: user.email, password: "password123" } }

    it "clears session[:user_id]" do
      delete logout_path
      expect(session[:user_id]).to be_nil
    end

    it "redirects to the root path" do
      delete logout_path
      expect(response).to redirect_to(root_path)
    end

    it "sets a logged-out flash notice" do
      delete logout_path
      expect(flash[:notice]).to be_present
    end

    it "makes protected pages inaccessible afterwards" do
      delete logout_path
      get dashboard_path
      expect(response).to redirect_to(login_path)
    end
  end
end
