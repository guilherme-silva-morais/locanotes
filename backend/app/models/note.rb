class Note < ApplicationRecord
  belongs_to :user

  # Strip surrounding whitespace at write time. This is applied via setter,
  # so validations see the trimmed value (whitespace-only titles fail presence).
  normalizes :title, with: ->(t) { t.to_s.strip }

  validates :title,
            presence: true,
            length: { minimum: 1, maximum: 120 }

  validates :content,
            length: { maximum: 10_000 },
            allow_blank: true

  # Tie-broken by id so paginated lists are stable across requests with equal
  # created_at timestamps (matters for cursor pagination in phase 2.10).
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
end
