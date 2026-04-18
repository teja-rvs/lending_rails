module PaymentsHelper
  def payment_due_hint(payment, today: Date.current)
    if payment.completed?
      return "Completed on #{payment.payment_date.to_fs(:long)}" if payment.payment_date

      return "Completed"
    end

    diff = (payment.due_date - today).to_i

    if diff.positive?
      "Due in #{pluralize(diff, 'day')}"
    elsif diff.zero?
      "Due today"
    else
      "Overdue by #{pluralize(diff.abs, 'day')}"
    end
  end
end
