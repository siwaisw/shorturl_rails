FactoryBot.define do
  factory :short_url do
    original_url { "https://example.com/some/long/path" }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_user do
      association :user
    end
  end
end
