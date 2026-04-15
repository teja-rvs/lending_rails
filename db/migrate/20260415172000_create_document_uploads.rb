class CreateDocumentUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :document_uploads, id: :uuid do |t|
      t.references :documentable, null: false, polymorphic: true, type: :uuid, index: false
      t.string :file_name, null: false
      t.text :description
      t.string :status, null: false, default: "active"
      t.datetime :superseded_at
      t.references :superseded_by, null: true, type: :uuid, foreign_key: { to_table: :document_uploads }, index: false
      t.references :uploaded_by, null: false, type: :uuid, foreign_key: { to_table: :users }, index: false
      t.timestamps
    end

    add_index :document_uploads, %i[documentable_type documentable_id]
    add_index :document_uploads, :status
    add_index :document_uploads, :uploaded_by_id
    add_index :document_uploads, :superseded_by_id
  end
end
