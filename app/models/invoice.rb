class Invoice < ApplicationRecord
  INVOICE_TYPES = %w[disbursement].freeze

  belongs_to :loan
  has_paper_trail

  monetize :amount_cents

  normalizes :invoice_number, with: ->(value) { value.to_s.squish.presence }
  normalizes :invoice_type, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :currency, with: ->(value) { value.to_s.squish.presence&.upcase }
  normalizes :notes, with: ->(value) { value.to_s.squish.presence }

  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_type, presence: true, inclusion: { in: INVOICE_TYPES }
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :issued_on, presence: true

  scope :disbursement, -> { where(invoice_type: "disbursement") }
  scope :ordered, -> { order(issued_on: :desc, created_at: :desc) }

  def self.next_invoice_number
    highest_sequence = where("invoice_number LIKE ?", "INV-%")
      .pluck(:invoice_number)
      .filter_map { |v| v.to_s.delete_prefix("INV-").to_i if v.to_s.match?(/\AINV-\d+\z/) }
      .max

    "INV-#{((highest_sequence || 0) + 1).to_s.rjust(4, "0")}"
  end

  def self.create_with_next_invoice_number!(**attributes)
    transaction do
      connection.execute("LOCK TABLE #{connection.quote_table_name(table_name)} IN EXCLUSIVE MODE")
      create!(**attributes, invoice_number: next_invoice_number)
    end
  end
end
