require "rails_helper"

RSpec.describe Borrowers::Create, type: :service do
  it "creates a borrower when the attributes are valid" do
    borrower = described_class.call(full_name: "Borrower One", phone_number: "98765 43210")

    expect(borrower).to be_persisted
    expect(borrower.phone_number_normalized).to eq("+919876543210")
  end

  it "returns a borrower with a duplicate-phone error when the unique index wins a race" do
    duplicate_error = ActiveRecord::RecordNotUnique.new("duplicate key value violates unique constraint")
    borrower = nil

    allow(Borrower).to receive(:new).and_wrap_original do |original, *args|
      borrower = original.call(*args)
      allow(borrower).to receive(:save).and_raise(duplicate_error)
      borrower
    end

    result = described_class.call(full_name: "Borrower Two", phone_number: "98765 43210")

    expect(result).to eq(borrower)
    expect(result).not_to be_persisted
    expect(result.errors[:phone_number]).to include("has already been taken")
  end
end
