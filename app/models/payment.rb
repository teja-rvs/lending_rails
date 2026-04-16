class Payment < ApplicationRecord
  include AASM

  belongs_to :loan
  has_paper_trail

  monetize :principal_amount_cents
  monetize :interest_amount_cents
  monetize :total_amount_cents
  monetize :late_fee_cents

  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :payment_mode, with: ->(value) { value.to_s.squish.presence&.downcase }
  normalizes :notes, with: ->(value) { value.to_s.squish.presence }

  validates :installment_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :due_date, presence: true
  validates :status, presence: true, inclusion: {
    in: ->(payment) { payment.class.aasm.states.map { |state| state.name.to_s } }
  }
  validates :principal_amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :interest_amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :late_fee_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :installment_number, uniqueness: { scope: :loan_id }
  validate :total_matches_components

  scope :ordered, -> { order(:installment_number, :due_date, :created_at) }

  aasm column: :status, whiny_transitions: true do
    state :pending, initial: true
    state :completed
    state :overdue

    event :mark_completed do
      transitions from: %i[pending overdue], to: :completed
    end

    event :mark_overdue do
      transitions from: :pending, to: :overdue
    end
  end

  def editable?
    pending? || overdue?
  end

  def status_label
    status.to_s.humanize
  end

  def status_tone
    case aasm.current_state
    when :completed
      :success
    when :overdue
      :warning
    else
      :neutral
    end
  end

  private
    def total_matches_components
      return if principal_amount_cents.blank? || interest_amount_cents.blank? || total_amount_cents.blank?

      expected_total = principal_amount_cents + interest_amount_cents
      return if total_amount_cents == expected_total

      errors.add(:total_amount_cents, "must equal principal plus interest")
    end
end
