require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  # ── Associations ───────────────────────────────────────────
  describe "associations" do
    it { is_expected.to have_many(:short_urls) }
  end

  # ── Password (has_secure_password) ─────────────────────────
  describe "has_secure_password" do
    it { is_expected.to have_secure_password }

    it "is invalid without a password on create" do
      user = build(:user, password: nil, password_confirmation: nil)
      expect(user).not_to be_valid
    end

    it "is invalid when password is shorter than 8 characters" do
      user = build(:user, password: "short7", password_confirmation: "short7")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "is valid with a password of exactly 8 characters" do
      user = build(:user, password: "exactly8", password_confirmation: "exactly8")
      expect(user).to be_valid
    end

    it "is invalid when password and confirmation do not match" do
      user = build(:user, password: "password123", password_confirmation: "different1")
      expect(user).not_to be_valid
    end

    describe "#authenticate" do
      let!(:user) { create(:user, password: "password123", password_confirmation: "password123") }

      it "returns the user when the password is correct" do
        expect(user.authenticate("password123")).to eq(user)
      end

      it "returns false when the password is incorrect" do
        expect(user.authenticate("wrongpassword")).to be(false)
      end
    end
  end

  # ── Email validations ──────────────────────────────────────
  describe "email validations" do
    it { is_expected.to validate_presence_of(:email) }

    it "is valid with a proper email address" do
      expect(build(:user, email: "hello@example.com")).to be_valid
    end

    it "is invalid without an @ symbol" do
      user = build(:user, email: "notanemail")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "is invalid with no domain after @" do
      user = build(:user, email: "user@")
      expect(user).not_to be_valid
    end

    describe "uniqueness" do
      it "is invalid when the same email already exists" do
        create(:user, email: "taken@example.com")
        duplicate = build(:user, email: "taken@example.com")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to include("has already been taken")
      end

      it "is case-insensitive — rejects an email that differs only by case" do
        create(:user, email: "taken@example.com")
        duplicate = build(:user, email: "TAKEN@EXAMPLE.COM")
        expect(duplicate).not_to be_valid
      end
    end
  end

  # ── before_save :downcase email ────────────────────────────
  describe "email normalisation (before_save)" do
    it "saves the email in lowercase" do
      user = create(:user, email: "UPPER@EXAMPLE.COM")
      expect(user.reload.email).to eq("upper@example.com")
    end

    it "downcases on update as well" do
      user = create(:user, email: "original@example.com")
      user.update!(email: "UPDATED@EXAMPLE.COM")
      expect(user.reload.email).to eq("updated@example.com")
    end
  end

  # ── has_many :short_urls ───────────────────────────────────
  describe "short_urls association" do
    it "nullifies user_id on short_urls when the user is destroyed" do
      user      = create(:user)
      short_url = create(:short_url, user: user)
      user.destroy
      expect(short_url.reload.user_id).to be_nil
    end
  end
end
