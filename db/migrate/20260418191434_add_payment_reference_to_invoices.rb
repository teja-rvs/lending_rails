class AddPaymentReferenceToInvoices < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_reference :invoices, :payment, type: :uuid, null: true, foreign_key: true, index: true
    end
  end
end
