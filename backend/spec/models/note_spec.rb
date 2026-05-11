require "rails_helper"

RSpec.describe Note, type: :model do
  subject { build(:note) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "title validations" do
    it { is_expected.to validate_presence_of(:title) }

    it "accepts a title with exactly 120 characters" do
      expect(build(:note, title: "a" * 120)).to be_valid
    end

    it "rejects a title with 121 characters" do
      note = build(:note, title: "a" * 121)
      expect(note).not_to be_valid
      expect(note.errors[:title]).to be_present
    end

    it "strips surrounding whitespace on assignment" do
      note = create(:note, title: "  hello  ")
      expect(note.title).to eq("hello")
    end

    it "rejects a whitespace-only title (strip leaves it blank)" do
      note = build(:note, title: "    ")
      expect(note).not_to be_valid
      expect(note.errors[:title]).to be_present
    end

    it "preserves unicode characters (accents, emoji)" do
      note = create(:note, title: "Título com café ☕")
      expect(note.reload.title).to eq("Título com café ☕")
    end
  end

  describe "content validations" do
    it "allows nil content" do
      expect(build(:note, content: nil)).to be_valid
    end

    it "allows empty content" do
      expect(build(:note, content: "")).to be_valid
    end

    it "accepts content with exactly 10000 characters" do
      expect(build(:note, content: "a" * 10_000)).to be_valid
    end

    it "rejects content with 10001 characters" do
      note = build(:note, content: "a" * 10_001)
      expect(note).not_to be_valid
      expect(note.errors[:content]).to be_present
    end

    it "preserves unicode characters" do
      note = create(:note, content: "Conteúdo com acentos e emoji 📝")
      expect(note.reload.content).to eq("Conteúdo com acentos e emoji 📝")
    end
  end

  describe ".recent_first scope" do
    # Scoped to a fresh user so these assertions don't depend on global Note
    # state (other suites may leave residual rows due to connection-pool quirks
    # outside of transactional_fixtures).
    let(:user) { create(:user) }

    it "orders by created_at descending" do
      old    = create(:note, user: user, created_at: 2.days.ago)
      newer  = create(:note, user: user, created_at: 1.day.ago)
      newest = create(:note, user: user, created_at: Time.current)

      expect(user.notes.recent_first).to eq([ newest, newer, old ])
    end

    it "breaks ties on created_at by id descending (stable ordering)" do
      ts = Time.current
      n1 = create(:note, user: user, created_at: ts)
      n2 = create(:note, user: user, created_at: ts)
      n3 = create(:note, user: user, created_at: ts)

      expect(user.notes.recent_first.pluck(:id)).to eq([ n3.id, n2.id, n1.id ])
    end
  end

  describe "cascade delete from user" do
    it "is destroyed when its user is destroyed" do
      user = create(:user)
      create_list(:note, 3, user: user)

      expect { user.destroy }.to change { Note.where(user_id: user.id).count }.from(3).to(0)
    end
  end
end
