require "rails_helper"

RSpec.describe Invoice, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:loan) }
  end

  describe "validations" do
    subject { build(:invoice, loan: create(:loan, :with_details)) }

    it { is_expected.to validate_presence_of(:invoice_number) }
    it { is_expected.to validate_uniqueness_of(:invoice_number) }
    it { is_expected.to validate_presence_of(:invoice_type) }
    it { is_expected.to validate_inclusion_of(:invoice_type).in_array(Invoice::INVOICE_TYPES) }
    it { is_expected.to validate_presence_of(:amount_cents) }
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:issued_on) }
  end

  describe "scopes" do
    it ".disbursement returns only disbursement invoices" do
      loan = create(:loan, :with_details)
      disbursement_inv = create(:invoice, loan: loan, invoice_type: "disbursement")

      expect(described_class.disbursement).to contain_exactly(disbursement_inv)
    end

    it ".ordered returns invoices by issued_on desc, created_at desc" do
      loan = create(:loan, :with_details)
      older = create(:invoice, loan: loan, issued_on: 2.days.ago)
      newer = create(:invoice, loan: loan, issued_on: Date.current)

      expect(described_class.ordered).to eq([newer, older])
    end
  end

  describe ".next_invoice_number" do
    it "returns INV-0001 when no invoices exist" do
      expect(described_class.next_invoice_number).to eq("INV-0001")
    end

    it "returns the next padded invoice number" do
      loan = create(:loan, :with_details)
      create(:invoice, loan: loan, invoice_number: "INV-0001")
      create(:invoice, loan: loan, invoice_number: "INV-0012")

      expect(described_class.next_invoice_number).to eq("INV-0013")
    end

    it "ignores non-matching invoice numbers" do
      loan = create(:loan, :with_details)
      create(:invoice, loan: loan, invoice_number: "INV-0005")
      create(:invoice, loan: loan, invoice_number: "OTHER-9999")

      expect(described_class.next_invoice_number).to eq("INV-0006")
    end
  end

  describe "monetize" do
    it "supports monetized amount" do
      loan = create(:loan, :with_details)
      invoice = build(:invoice, loan: loan, amount_cents: 4_500_000)

      expect(invoice.amount).to eq(Money.new(4_500_000, "INR"))
    end
  end

  describe "audit trail" do
    it "records versions with paper trail" do
      loan = create(:loan, :with_details)
      invoice = create(:invoice, loan: loan)

      expect(invoice.versions.pluck(:event)).to include("create")
    end
  end
end
