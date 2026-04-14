# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_14_111000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "borrowers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.string "phone_number", null: false
    t.string "phone_number_normalized", null: false
    t.datetime "updated_at", null: false
    t.index ["full_name"], name: "index_borrowers_on_full_name"
    t.index ["phone_number_normalized"], name: "index_borrowers_on_phone_number_normalized", unique: true
  end

  create_table "double_entry_account_balances", force: :cascade do |t|
    t.string "account", null: false
    t.bigint "balance", null: false
    t.datetime "created_at", null: false
    t.string "scope"
    t.datetime "updated_at", null: false
    t.index ["account"], name: "index_account_balances_on_account"
    t.index ["scope", "account"], name: "index_account_balances_on_scope_and_account", unique: true
  end

  create_table "double_entry_line_checks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "errors_found", null: false
    t.bigint "last_line_id", null: false
    t.text "log"
    t.datetime "updated_at", null: false
    t.index ["created_at", "last_line_id"], name: "line_checks_created_at_last_line_id_idx"
  end

  create_table "double_entry_lines", force: :cascade do |t|
    t.string "account", null: false
    t.bigint "amount", null: false
    t.bigint "balance", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.uuid "detail_id"
    t.string "detail_type"
    t.jsonb "metadata"
    t.string "partner_account", null: false
    t.uuid "partner_id"
    t.string "partner_scope"
    t.string "scope"
    t.datetime "updated_at", null: false
    t.index ["account", "code", "created_at"], name: "lines_account_code_created_at_idx"
    t.index ["account", "created_at"], name: "lines_account_created_at_idx"
    t.index ["scope", "account", "created_at"], name: "lines_scope_account_created_at_idx"
    t.index ["scope", "account", "id"], name: "lines_scope_account_id_idx"
  end

  create_table "loan_applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "application_number", null: false
    t.string "borrower_full_name_snapshot"
    t.uuid "borrower_id", null: false
    t.string "borrower_phone_number_snapshot"
    t.datetime "created_at", null: false
    t.text "decision_notes"
    t.string "proposed_interest_mode"
    t.text "request_notes"
    t.bigint "requested_amount_cents"
    t.string "requested_repayment_frequency"
    t.integer "requested_tenure_in_months"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["application_number"], name: "index_loan_applications_on_application_number", unique: true
    t.index ["borrower_id"], name: "index_loan_applications_on_borrower_id"
    t.index ["proposed_interest_mode"], name: "index_loan_applications_on_proposed_interest_mode"
    t.index ["requested_repayment_frequency"], name: "index_loan_applications_on_requested_repayment_frequency"
    t.index ["status"], name: "index_loan_applications_on_status"
  end

  create_table "loans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "borrower_id", null: false
    t.datetime "created_at", null: false
    t.uuid "loan_application_id"
    t.string "loan_number", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["borrower_id"], name: "index_loans_on_borrower_id"
    t.index ["loan_application_id"], name: "index_loans_on_loan_application_id"
    t.index ["loan_number"], name: "index_loans_on_loan_number", unique: true
    t.index ["status"], name: "index_loans_on_status"
  end

  create_table "review_steps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "loan_application_id", null: false
    t.integer "position", null: false
    t.string "status", null: false
    t.string "step_key", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_application_id", "position"], name: "index_review_steps_on_loan_application_id_and_position", unique: true
    t.index ["loan_application_id", "step_key"], name: "index_review_steps_on_loan_application_id_and_step_key", unique: true
    t.index ["loan_application_id"], name: "index_review_steps_on_loan_application_id"
    t.index ["status"], name: "index_review_steps_on_status"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.string "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "loan_applications", "borrowers"
  add_foreign_key "loans", "borrowers"
  add_foreign_key "loans", "loan_applications"
  add_foreign_key "review_steps", "loan_applications"
  add_foreign_key "sessions", "users"
end
