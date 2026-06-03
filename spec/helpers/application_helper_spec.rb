require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#time_remaining" do
    it "returns expired when expires_at is in the past" do
      result = helper.time_remaining(1.second.ago)
      expect(result).to eq({ label: "Expired", expired: true })
    end

    it "returns expired when expires_at is exactly now" do
      result = helper.time_remaining(Time.current)
      expect(result[:expired]).to be true
    end

    it "formats as years and months when >= 365 days remain" do
      result = helper.time_remaining(400.days.from_now)
      expect(result[:label]).to match(/\dy \d+mo/)
      expect(result[:expired]).to be false
    end

    it "formats as months and days when >= 30 days remain" do
      result = helper.time_remaining(45.days.from_now)
      expect(result[:label]).to match(/\dmo \d+d/)
      expect(result[:expired]).to be false
    end

    it "formats as days and hours when >= 1 day remains" do
      result = helper.time_remaining(3.days.from_now)
      expect(result[:label]).to match(/\d+d \d+h/)
      expect(result[:expired]).to be false
    end

    it "formats as hours and minutes when < 1 day but >= 1 hour remains" do
      result = helper.time_remaining(5.hours.from_now)
      expect(result[:label]).to match(/\d+h \d+m/)
      expect(result[:expired]).to be false
    end

    it "formats as minutes only when < 1 hour remains" do
      result = helper.time_remaining(45.minutes.from_now)
      expect(result[:label]).to match(/\d+m/)
      expect(result[:label]).not_to include("h")
      expect(result[:expired]).to be false
    end
  end
end
