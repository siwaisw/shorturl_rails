require "rails_helper"

RSpec.describe ShortUrl, type: :model do
  # ── Associations ───────────────────────────────────────────
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
  end

  # ── Validations ────────────────────────────────────────────
  describe "validations" do
    it { is_expected.to validate_presence_of(:original_url) }

    describe "original_url format" do
      it "is valid with an HTTP URL" do
        expect(build(:short_url, original_url: "http://example.com")).to be_valid
      end

      it "is valid with an HTTPS URL" do
        expect(build(:short_url, original_url: "https://example.com/path?q=1#anchor")).to be_valid
      end

      it "is invalid with an FTP URL" do
        record = build(:short_url, original_url: "ftp://example.com")
        expect(record).not_to be_valid
        expect(record.errors[:original_url]).to include("must be a valid HTTP or HTTPS URL")
      end

      it "is invalid when the scheme is missing" do
        record = build(:short_url, original_url: "example.com/path")
        expect(record).not_to be_valid
        expect(record.errors[:original_url]).to include("must be a valid HTTP or HTTPS URL")
      end

      it "is invalid with a plain string" do
        record = build(:short_url, original_url: "not a url at all")
        expect(record).not_to be_valid
        expect(record.errors[:original_url]).to include("must be a valid HTTP or HTTPS URL")
      end

      it "is invalid with only a scheme and no host" do
        record = build(:short_url, original_url: "https://")
        expect(record).not_to be_valid
        expect(record.errors[:original_url]).to include("must be a valid HTTP or HTTPS URL")
      end
    end
  end

  # ── .encode_base62 ─────────────────────────────────────────
  describe ".encode_base62" do
    it "encodes 0 as seven zeros" do
      expect(described_class.encode_base62(0)).to eq("0000000")
    end

    it "encodes 1 as '0000001'" do
      expect(described_class.encode_base62(1)).to eq("0000001")
    end

    it "encodes 12345 as '00003d7' (README example)" do
      expect(described_class.encode_base62(12345)).to eq("00003d7")
    end

    it "always returns exactly KEY_LENGTH characters" do
      [ 1, 100, 999_999, 62**6 ].each do |n|
        expect(described_class.encode_base62(n).length).to eq(ShortUrl::KEY_LENGTH)
      end
    end

    it "only uses characters from the Base62 alphabet" do
      expect(described_class.encode_base62(99_999)).to match(/\A[0-9a-zA-Z]+\z/)
    end

    it "produces unique keys for different IDs" do
      keys = (1..10).map { |n| described_class.encode_base62(n) }
      expect(keys.uniq.length).to eq(10)
    end
  end

  # ── Callbacks ──────────────────────────────────────────────
  describe "callbacks" do
    describe "#set_expiry (before_create)" do
      it "sets expires_at to approximately 1 year from now by default" do
        short_url = create(:short_url)
        expect(short_url.expires_at).to be_within(1.minute).of(1.year.from_now)
      end

      it "preserves a manually provided expires_at" do
        custom_expiry = 3.months.from_now
        short_url = create(:short_url, expires_at: custom_expiry)
        expect(short_url.expires_at).to be_within(1.second).of(custom_expiry)
      end
    end

    describe "#assign_short_key (after_create)" do
      it "sets short_key after the record is persisted" do
        short_url = create(:short_url)
        expect(short_url.short_key).not_to be_nil
      end

      it "sets short_key to the Base62 encoding of the record's own ID" do
        short_url = create(:short_url)
        expect(short_url.short_key).to eq(described_class.encode_base62(short_url.id))
      end

      it "assigns unique keys to separate records" do
        first  = create(:short_url)
        second = create(:short_url)
        expect(first.short_key).not_to eq(second.short_key)
      end
    end
  end

  # ── :expired trait sanity check ────────────────────────────
  describe ":expired factory trait" do
    it "creates a record whose expires_at is in the past" do
      expect(create(:short_url, :expired).expires_at).to be < Time.current
    end
  end
end
