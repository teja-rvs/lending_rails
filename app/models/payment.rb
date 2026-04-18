class Payment < ApplicationRecord
  include AASM

  PAYMENT_MODES = %w[cash upi bank_transfer cheque other].freeze

  belongs_to :loan
  has_one :invoice, dependent: :restrict_with_exception
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

  validates :payment_date, presence: true, if: :completed?
  validates :payment_mode, presence: true, inclusion: { in: PAYMENT_MODES }, if: :completed?
  validates :completed_at, presence: true, if: :completed?
  validate :payment_date_not_in_future, if: -> { completed? && payment_date.present? }

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

  def readonly?
    return false if new_record?

    status_was == "completed"
  end

  def payment_mode_label
    payment_mode.to_s.humanize.presence
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

    def payment_date_not_in_future
      return if payment_date <= Date.current

      errors.add(:payment_date, "cannot be in the future")
    end
end
