require "rails_helper"

RSpec.describe "Users", type: :request do
  describe "GET /signup" do
    context "when not logged in" do
      it "returns 200" do
        get signup_path
        expect(response.status).to eq(200)
      end
    end

    context "when already logged in" do
      let!(:user) { create(:user) }

      before { post login_path, params: { email: user.email, password: "password123" } }

      it "redirects to the dashboard" do
        get signup_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe "POST /signup" do
    let(:valid_params) do
      { user: { email: "new@example.com",
                password: "password123",
                password_confirmation: "password123" } }
    end

    context "with valid params" do
      it "creates a new user" do
        expect { post signup_path, params: valid_params }.to change(User, :count).by(1)
      end

      it "logs the new user in by setting session[:user_id]" do
        post signup_path, params: valid_params
        expect(session[:user_id]).to eq(User.last.id)
      end

      it "redirects to the dashboard" do
        post signup_path, params: valid_params
        expect(response).to redirect_to(dashboard_path)
      end

      it "sets a welcome flash notice" do
        post signup_path, params: valid_params
        expect(flash[:notice]).to be_present
      end

      it "stores the email in lowercase regardless of input casing" do
        post signup_path, params: valid_params.deep_merge(user: { email: "NEW@EXAMPLE.COM" })
        expect(User.last.email).to eq("new@example.com")
      end
    end

    context "with a blank email" do
      let(:blank_email_params) do
        { user: { email: "", password: "password123", password_confirmation: "password123" } }
      end

      it "does not create a user" do
        expect { post signup_path, params: blank_email_params }.not_to change(User, :count)
      end

      it "responds with 422 Unprocessable Entity" do
        post signup_path, params: blank_email_params
        expect(response.status).to eq(422)
      end

      it "sets flash[:alert]" do
        post signup_path, params: blank_email_params
        expect(flash[:alert]).to be_present
      end
    end

    context "with an invalid email format" do
      it "does not create a user" do
        expect {
          post signup_path, params: { user: { email: "notanemail",
                                              password: "password123",
                                              password_confirmation: "password123" } }
        }.not_to change(User, :count)
      end
    end

    context "with a duplicate email" do
      before { create(:user, email: "taken@example.com") }

      it "does not create a user" do
        expect {
          post signup_path, params: { user: { email: "taken@example.com",
                                              password: "password123",
                                              password_confirmation: "password123" } }
        }.not_to change(User, :count)
      end

      it "rejects the duplicate even when casing differs" do
        expect {
          post signup_path, params: { user: { email: "TAKEN@EXAMPLE.COM",
                                              password: "password123",
                                              password_confirmation: "password123" } }
        }.not_to change(User, :count)
      end

      it "responds with 422" do
        post signup_path, params: { user: { email: "taken@example.com",
                                            password: "password123",
                                            password_confirmation: "password123" } }
        expect(response.status).to eq(422)
      end
    end

    context "with a password shorter than 8 characters" do
      it "does not create a user" do
        expect {
          post signup_path, params: { user: { email: "new@example.com",
                                              password: "short7",
                                              password_confirmation: "short7" } }
        }.not_to change(User, :count)
      end
    end

    context "with mismatched password confirmation" do
      it "does not create a user" do
        expect {
          post signup_path, params: { user: { email: "new@example.com",
                                              password: "password123",
                                              password_confirmation: "different1" } }
        }.not_to change(User, :count)
      end
    end
  end
end
