class Loan < ApplicationRecord
  STATUSES = [
    "active",
    "closed",
    "overdue"
  ].freeze

  belongs_to :borrower
  belongs_to :loan_application, optional: true

  normalizes :loan_number, with: ->(value) { value.to_s.squish.presence }
  normalizes :status, with: ->(value) { value.to_s.squish.presence&.downcase }

  validates :loan_number, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def status_tone
    case status
    when "active"
      :success
    when "overdue"
      :danger
    else
      :neutral
    end
  end

  def status_label
    status.to_s.split.map(&:capitalize).join(" ")
  end
end
