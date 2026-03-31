require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to validate_presence_of(:email_address) }
  it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }

  it 'normalizes the email address before validation' do
    user.email_address = '  ADMIN@Example.COM  '

    user.validate

    expect(user.email_address).to eq('admin@example.com')
  end

  describe ".admin_email_addresses" do
    around do |example|
      original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
      example.run
    ensure
      ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
    end

    it "normalizes, trims, and drops blank configured admin addresses" do
      ENV["ADMIN_EMAIL_ADDRESSES"] = " Admin@example.com, backup@example.com , ,"

      expect(described_class.admin_email_addresses).to eq(
        ["admin@example.com", "backup@example.com"]
      )
    end
  end

  describe "#admin?" do
    around do |example|
      original_admin_addresses = ENV["ADMIN_EMAIL_ADDRESSES"]
      ENV["ADMIN_EMAIL_ADDRESSES"] = "admin@example.com"
      example.run
    ensure
      ENV["ADMIN_EMAIL_ADDRESSES"] = original_admin_addresses
    end

    it "returns true for configured admin email addresses" do
      user.email_address = "admin@example.com"

      expect(user).to be_admin
    end

    it "returns false for non-admin email addresses" do
      user.email_address = "operator@example.com"

      expect(user).not_to be_admin
    end
  end
end
