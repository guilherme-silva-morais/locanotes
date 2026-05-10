require "rails_helper"

RSpec.describe CursorPagination do
  let(:user)  { create(:user) }
  let(:scope) { user.notes.recent_first }

  describe "without a cursor" do
    it "returns the first page in recent-first order" do
      n1 = create(:note, user: user)
      n2 = create(:note, user: user)
      n3 = create(:note, user: user)

      result = described_class.new(scope, limit: 2).call
      expect(result.records.map(&:id)).to eq([ n3.id, n2.id ])
      expect(result.has_more).to be(true)
      expect(result.next_cursor).to be_present
    end

    it "returns has_more=false and next_cursor=nil when fewer items than limit" do
      create_list(:note, 2, user: user)
      result = described_class.new(scope, limit: 5).call
      expect(result.has_more).to be(false)
      expect(result.next_cursor).to be_nil
    end

    it "returns empty when the scope is empty" do
      result = described_class.new(scope).call
      expect(result.records).to be_empty
      expect(result.has_more).to be(false)
      expect(result.next_cursor).to be_nil
    end
  end

  describe "paginating across pages" do
    it "advances through pages without duplicating or skipping items" do
      created = create_list(:note, 5, user: user)
      expected = created.reverse # recent-first

      first  = described_class.new(scope, limit: 2).call
      second = described_class.new(scope, cursor: first.next_cursor, limit: 2).call
      third  = described_class.new(scope, cursor: second.next_cursor, limit: 2).call

      expect(first.records).to eq(expected[0..1])
      expect(second.records).to eq(expected[2..3])
      expect(third.records).to eq([ expected[4] ])
      expect(third.has_more).to be(false)
      expect(third.next_cursor).to be_nil

      # Overall: every item appears exactly once across the three pages.
      collected = first.records + second.records + third.records
      expect(collected).to eq(expected)
    end

    it "is stable when multiple rows share the same created_at (tie-breaks by id)" do
      ts = Time.current
      a = create(:note, user: user, created_at: ts)
      b = create(:note, user: user, created_at: ts)
      c = create(:note, user: user, created_at: ts)

      first = described_class.new(scope, limit: 2).call
      expect(first.records.map(&:id)).to eq([ c.id, b.id ])

      second = described_class.new(scope, cursor: first.next_cursor, limit: 2).call
      expect(second.records.map(&:id)).to eq([ a.id ])
    end

    it "is not affected by older items inserted concurrently after the first page" do
      # Pin timestamps so the ordering is unambiguous regardless of insertion speed.
      newest = create(:note, user: user, created_at: 1.minute.ago)
      middle = create(:note, user: user, created_at: 5.minutes.ago)
      oldest = create(:note, user: user, created_at: 1.day.ago)

      first = described_class.new(scope, limit: 2).call
      expect(first.records).to eq([ newest, middle ])

      # Simulate a concurrent insert of an even-older note AFTER the first page
      # was read. It should appear at the end of the listing, not "skip" oldest.
      even_older = create(:note, user: user, created_at: 2.days.ago)

      second = described_class.new(scope, cursor: first.next_cursor, limit: 5).call
      expect(second.records).to eq([ oldest, even_older ])
      expect(second.records).not_to include(newest, middle)
    end
  end

  describe "limit normalization" do
    it "defaults to 20 when limit is nil" do
      create_list(:note, 25, user: user)
      expect(described_class.new(scope).call.records.size).to eq(20)
    end

    it "caps at MAX_LIMIT (100)" do
      create_list(:note, 105, user: user)
      expect(described_class.new(scope, limit: 999).call.records.size).to eq(100)
    end

    it "uses default when limit is 0 or negative" do
      create_list(:note, 25, user: user)
      expect(described_class.new(scope, limit: 0).call.records.size).to eq(20)
      expect(described_class.new(scope, limit: -1).call.records.size).to eq(20)
    end

    it "accepts string limit values (params come in as strings)" do
      create_list(:note, 5, user: user)
      expect(described_class.new(scope, limit: "3").call.records.size).to eq(3)
    end
  end

  describe "invalid cursors" do
    it "raises InvalidCursor for non-base64 input" do
      expect { described_class.new(scope, cursor: "not base64 !!").call }
        .to raise_error(described_class::InvalidCursor)
    end

    it "raises InvalidCursor when the decoded payload has no separator" do
      bad = Base64.urlsafe_encode64("no-separator-here", padding: false)
      expect { described_class.new(scope, cursor: bad).call }
        .to raise_error(described_class::InvalidCursor)
    end

    it "raises InvalidCursor for an unparseable timestamp" do
      bad = Base64.urlsafe_encode64("not-a-timestamp:1", padding: false)
      expect { described_class.new(scope, cursor: bad).call }
        .to raise_error(described_class::InvalidCursor)
    end

    it "raises InvalidCursor for a non-integer id" do
      bad = Base64.urlsafe_encode64("#{Time.current.iso8601(6)}:not-an-int", padding: false)
      expect { described_class.new(scope, cursor: bad).call }
        .to raise_error(described_class::InvalidCursor)
    end
  end
end
