require "rails_helper"

RSpec.describe NotePolicy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }
  let(:note)  { create(:note, user: owner) }

  describe "#index? / #create?" do
    it "allows any authenticated user" do
      expect(NotePolicy.new(owner, Note).index?).to be(true)
      expect(NotePolicy.new(owner, Note).create?).to be(true)
    end
  end

  %i[show? update? destroy?].each do |action|
    describe "##{action}" do
      it "allows the owner" do
        expect(NotePolicy.new(owner, note).public_send(action)).to be(true)
      end

      it "denies a different user" do
        expect(NotePolicy.new(other, note).public_send(action)).to be(false)
      end
    end
  end

  describe "Scope#resolve" do
    it "returns only the user's own notes" do
      mine    = create(:note, user: owner)
      _theirs = create(:note, user: other)

      scope = NotePolicy::Scope.new(owner, Note).resolve
      expect(scope).to contain_exactly(mine)
    end
  end
end
