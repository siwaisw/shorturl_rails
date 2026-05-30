FactoryBot.define do
  factory :short_url do
    original_url { "https://chicken-nuggets.com/some/long/path" }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :soft_deleted do
      expires_at { 2.days.ago }
      deleted_at { 1.hour.ago }
    end

    trait :with_user do
      association :user
    end
  end
end
