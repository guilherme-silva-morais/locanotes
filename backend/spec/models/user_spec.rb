require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
  end

  describe "email_address validations" do
    it { is_expected.to validate_presence_of(:email_address) }

    it { is_expected.to allow_value("user@example.com").for(:email_address) }
    it { is_expected.to allow_value("user+tag@sub.example.co.uk").for(:email_address) }
    it { is_expected.not_to allow_value("not-an-email").for(:email_address) }
    it { is_expected.not_to allow_value("user@").for(:email_address) }
    it { is_expected.not_to allow_value("@example.com").for(:email_address) }

    it "rejects duplicates case-insensitively" do
      create(:user, email_address: "user@example.com")
      duplicate = build(:user, email_address: "USER@Example.com")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email_address]).to include(I18n.t("errors.messages.taken"))
    end

    it "rejects emails with non-ASCII characters in the local part" do
      # URI::MailTo::EMAIL_REGEXP allows only ASCII; IDN/unicode would need
      # punycode normalization upstream, which we don't do.
      expect(build(:user, email_address: "üser@example.com")).not_to be_valid
    end

    it "rejects emails with non-ASCII characters in the domain" do
      expect(build(:user, email_address: "user@éxample.com")).not_to be_valid
    end
  end

  describe "email normalization" do
    it "strips surrounding whitespace and downcases on save" do
      user = User.create!(email_address: "  USER@Example.com  ", password: "Password123")
      expect(user.email_address).to eq("user@example.com")
    end
  end

  describe "password validations" do
    it "rejects fewer than 8 characters" do
      user = build(:user, password: "Ab1")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "accepts exactly 8 characters with a letter and a digit" do
      user = build(:user, password: "Abcdef12")
      expect(user).to be_valid
    end

    it "rejects a password without any letter" do
      user = build(:user, password: "12345678")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "rejects a password without any digit" do
      user = build(:user, password: "abcdefgh")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "is required on create" do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "accepts whitespace inside the password (entropy is preserved)" do
      expect(build(:user, password: "Ab 12345")).to be_valid
    end

    it "accepts password at the bcrypt boundary (72 characters)" do
      password = "a" + ("1" * 71)
      expect(password.length).to eq(72)
      expect(build(:user, password: password)).to be_valid
    end

    it "rejects password exceeding the bcrypt limit (73 characters)" do
      password = "a" + ("1" * 72)
      expect(password.length).to eq(73)
      user = build(:user, password: password)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end
end
