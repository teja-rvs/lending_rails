class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :loan, type: :uuid, null: false, foreign_key: true
      t.string :invoice_number, null: false
      t.string :invoice_type, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "INR"
      t.date :issued_on, null: false
      t.text :notes

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :invoice_type
    add_index :invoices, :issued_on
  end
end
