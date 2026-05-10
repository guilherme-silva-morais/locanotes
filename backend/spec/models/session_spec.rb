require "rails_helper"

RSpec.describe Session, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "creation" do
    it "is valid with required attributes" do
      expect(build(:session)).to be_valid
    end

    it "is invalid without a user" do
      session = build(:session, user: nil)
      expect(session).not_to be_valid
      expect(session.errors[:user]).to be_present
    end

    it "persists user_agent and ip_address" do
      session = create(:session, user_agent: "Mozilla/5.0", ip_address: "192.168.1.1")
      session.reload
      expect(session.user_agent).to eq("Mozilla/5.0")
      expect(session.ip_address).to eq("192.168.1.1")
    end

    it "allows nil user_agent and ip_address" do
      # Brief doesn't require them; they're audit metadata, not auth-critical.
      session = build(:session, user_agent: nil, ip_address: nil)
      expect(session).to be_valid
    end

    it "stamps created_at automatically" do
      session = create(:session)
      expect(session.created_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "cascade delete from user" do
    it "is destroyed when its user is destroyed" do
      user = create(:user)
      create(:session, user: user)
      create(:session, user: user)

      expect { user.destroy }.to change { Session.where(user_id: user.id).count }.from(2).to(0)
    end
  end
end
