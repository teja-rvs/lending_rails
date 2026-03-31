class Borrower < ApplicationRecord
  normalizes :full_name, with: ->(value) { value.to_s.squish.presence }
  normalizes :phone_number, with: ->(value) { value.to_s.squish.presence }

  before_validation :normalize_phone_number

  validates :full_name, presence: true
  validates :phone_number, presence: true
  validate :phone_number_must_normalize
  validate :phone_number_must_be_unique

  def self.normalize_phone_number(value)
    parse_phone_number(value)&.full_e164
  end

  def self.parse_phone_number(value)
    return if value.blank?

    parsed_phone = Phonelib.parse(value)
    return parsed_phone if parsed_phone.valid?

    digits_only = value.to_s.gsub(/\D/, "")
    return if digits_only.blank?

    parsed_phone = Phonelib.parse(digits_only, Phonelib.default_country)
    return parsed_phone if parsed_phone.valid?
  end

  def mark_phone_number_taken!
    errors.add(:phone_number, :taken) unless errors.added?(:phone_number, :taken)
    self
  end

  private

  def normalize_phone_number
    self.phone_number_normalized = self.class.normalize_phone_number(phone_number)
  end

  def phone_number_must_normalize
    return if phone_number.blank? || phone_number_normalized.present?

    errors.add(:phone_number, "is invalid")
  end

  def phone_number_must_be_unique
    return if phone_number_normalized.blank?

    scope = self.class.where(phone_number_normalized: phone_number_normalized)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:phone_number, :taken) if scope.exists?
  end
end
