require 'rails_helper'

RSpec.describe Borrower, type: :model do
  subject(:borrower) { build(:borrower) }

  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_presence_of(:phone_number) }

  describe "deletion protection" do
    subject { create(:borrower) }

    it_behaves_like "deletion protected"
  end

  describe 'version tracking' do
    it 'responds to versions' do
      expect(Borrower.new).to respond_to(:versions)
    end

    it 'creates a PaperTrail version on create' do
      borrower = create(:borrower)

      expect(borrower.versions.count).to eq(1)
      expect(borrower.versions.last.event).to eq("create")
    end
  end

  describe 'identity' do
    it 'uses uuid primary keys' do
      saved_borrower = create(:borrower)

      expect(described_class.type_for_attribute('id').type).to eq(:uuid)
      expect(saved_borrower.id).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe 'phone normalization' do
    it 'stores a canonical searchable phone value before validation' do
      borrower.phone_number = ' 98765 43210 '

      borrower.validate

      expect(borrower.phone_number_normalized).to eq('+919876543210')
    end

    it 'normalizes equivalent phone formats to the same canonical value' do
      first = build(:borrower, phone_number: '98765 43210')
      second = build(:borrower, phone_number: '+91 98765 43210')

      first.validate
      second.validate

      expect(first.phone_number_normalized).to eq('+919876543210')
      expect(second.phone_number_normalized).to eq(first.phone_number_normalized)
    end

    it 'rejects phone numbers that cannot be normalized' do
      borrower.phone_number = 'not-a-phone-number'

      expect(borrower).not_to be_valid
      expect(borrower.phone_number_normalized).to be_nil
      expect(borrower.errors[:phone_number]).to include('is invalid')
    end
  end

  describe 'duplicate protection' do
    it 'rejects duplicate borrowers for the same logical phone number' do
      create(:borrower, phone_number: '98765 43210')
      duplicate = build(:borrower, phone_number: '+91 98765 43210')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:phone_number]).to include('has already been taken')
    end

    it 'enforces uniqueness at the database layer' do
      create(:borrower, phone_number: '98765 43210')
      duplicate = build(:borrower, phone_number: '+91 98765 43210')
      duplicate.phone_number_normalized = described_class.normalize_phone_number(duplicate.phone_number)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
