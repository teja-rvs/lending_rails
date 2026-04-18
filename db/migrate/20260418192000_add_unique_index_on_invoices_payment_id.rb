class AddUniqueIndexOnInvoicesPaymentId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :invoices,
              :payment_id,
              unique: true,
              where: "payment_id IS NOT NULL",
              name: "index_invoices_on_payment_id_unique_when_present",
              algorithm: :concurrently
  end
end
