FactoryBot.define do
  factory :note do
    user
    sequence(:title) { |n| "Note title ##{n}" }
    content { "Lorem ipsum dolor sit amet." }
  end
end
