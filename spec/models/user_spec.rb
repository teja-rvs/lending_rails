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
end
