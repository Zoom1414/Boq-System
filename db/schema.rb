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

ActiveRecord::Schema[8.1].define(version: 2026_09_18_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.text "summary", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "boq_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "master_boq_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["master_boq_id", "position"], name: "index_boq_categories_on_master_boq_id_and_position"
    t.index ["master_boq_id"], name: "index_boq_categories_on_master_boq_id"
  end

  create_table "boq_items", force: :cascade do |t|
    t.bigint "boq_category_id", null: false
    t.string "code", null: false
    t.bigint "contractor_id"
    t.string "contractor_name"
    t.datetime "created_at", null: false
    t.decimal "labor_paid_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "labor_remaining_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "labor_total", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "labor_unit_price", precision: 18, scale: 2, default: "0.0", null: false
    t.integer "lock_version", default: 0, null: false
    t.decimal "material_quantity", precision: 18, scale: 4, default: "0.0", null: false
    t.decimal "material_remaining_qty", precision: 18, scale: 4, default: "0.0", null: false
    t.decimal "material_total", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "material_unit_price", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "material_used_qty", precision: 18, scale: 4, default: "0.0", null: false
    t.string "name", null: false
    t.text "note"
    t.decimal "progress_percentage", precision: 5, scale: 2, default: "0.0", null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["boq_category_id", "code"], name: "index_boq_items_on_boq_category_id_and_code", unique: true
    t.index ["boq_category_id"], name: "index_boq_items_on_boq_category_id"
    t.index ["contractor_id"], name: "index_boq_items_on_contractor_id"
    t.index ["contractor_name"], name: "index_boq_items_on_contractor_name"
    t.check_constraint "material_quantity >= 0::numeric AND material_used_qty >= 0::numeric AND material_unit_price >= 0::numeric AND labor_unit_price >= 0::numeric AND labor_paid_amount >= 0::numeric AND progress_percentage >= 0::numeric AND progress_percentage <= 100::numeric", name: "boq_items_nonnegative_inputs"
  end

  create_table "contractors", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "bank_account_name"
    t.string "bank_account_number"
    t.string "bank_name"
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.string "full_name", null: false
    t.string "last_name"
    t.text "note"
    t.string "phone"
    t.string "trade"
    t.datetime "updated_at", null: false
    t.index "lower((full_name)::text)", name: "index_contractors_on_lower_full_name", unique: true
    t.index ["bank_account_number"], name: "index_contractors_on_bank_account_number", unique: true, where: "(bank_account_number IS NOT NULL)"
    t.index ["trade"], name: "index_contractors_on_trade"
    t.check_constraint "bank_account_number IS NULL OR bank_account_number::text ~ '^[0-9]{10,15}$'::text", name: "contractors_bank_account_digits"
  end

  create_table "document_sequences", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "value", default: 0, null: false
    t.index ["name"], name: "index_document_sequences_on_name", unique: true
  end

  create_table "house_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "plan_code", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "plan_code"], name: "index_house_plans_on_project_id_and_plan_code", unique: true
    t.index ["project_id"], name: "index_house_plans_on_project_id"
  end

  create_table "labor_draw_items", force: :cascade do |t|
    t.bigint "boq_item_id", null: false
    t.decimal "budget_total", precision: 18, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "labor_draw_request_id", null: false
    t.decimal "paid_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "quantity", precision: 18, scale: 4, default: "0.0", null: false
    t.decimal "remaining_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "requested_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "unit_price", precision: 18, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.string "work_description", null: false
    t.index ["boq_item_id"], name: "index_labor_draw_items_on_boq_item_id"
    t.index ["labor_draw_request_id", "boq_item_id"], name: "idx_on_labor_draw_request_id_boq_item_id_c6eef677f9", unique: true
    t.index ["labor_draw_request_id"], name: "index_labor_draw_items_on_labor_draw_request_id"
    t.check_constraint "quantity > 0::numeric AND unit_price >= 0::numeric AND requested_amount > 0::numeric", name: "labor_draw_items_valid_amounts"
  end

  create_table "labor_draw_requests", force: :cascade do |t|
    t.text "admin_note"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.boolean "budget_override", default: false, null: false
    t.text "cancel_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.bigint "contractor_id"
    t.string "contractor_name", null: false
    t.datetime "created_at", null: false
    t.string "dv_number", null: false
    t.bigint "house_plan_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "override_reason"
    t.string "payee_bank_account_name"
    t.string "payee_bank_account_number"
    t.string "payee_bank_name"
    t.bigint "project_id", null: false
    t.date "request_date", null: false
    t.string "status", default: "pending", null: false
    t.string "submission_key"
    t.decimal "total_requested_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["approved_by_id"], name: "index_labor_draw_requests_on_approved_by_id"
    t.index ["cancelled_by_id"], name: "index_labor_draw_requests_on_cancelled_by_id"
    t.index ["contractor_id"], name: "index_labor_draw_requests_on_contractor_id"
    t.index ["dv_number"], name: "index_labor_draw_requests_on_dv_number", unique: true
    t.index ["house_plan_id"], name: "index_labor_draw_requests_on_house_plan_id"
    t.index ["project_id"], name: "index_labor_draw_requests_on_project_id"
    t.index ["status", "request_date"], name: "index_labor_draw_requests_on_status_and_request_date"
    t.index ["submission_key"], name: "index_labor_draw_requests_on_submission_key", unique: true
    t.index ["user_id"], name: "index_labor_draw_requests_on_user_id"
    t.check_constraint "status::text <> 'approved'::text OR approved_by_id IS NOT NULL AND approved_at IS NOT NULL", name: "labor_draw_requests_approval_audit"
    t.check_constraint "status::text <> 'cancelled'::text OR cancelled_by_id IS NOT NULL AND cancelled_at IS NOT NULL", name: "labor_draw_requests_cancel_audit"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying, 'cancelled'::character varying]::text[])", name: "labor_draw_requests_valid_status"
  end

  create_table "login_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "ip_address"
    t.string "reason"
    t.boolean "success", default: false, null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["created_at"], name: "index_login_events_on_created_at"
    t.index ["user_id"], name: "index_login_events_on_user_id"
  end

  create_table "master_boqs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "house_plan_id", null: false
    t.string "status", default: "draft", null: false
    t.decimal "total_labor_budget", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "total_material_budget", precision: 18, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["house_plan_id"], name: "index_master_boqs_on_house_plan_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'archived'::character varying]::text[])", name: "master_boqs_valid_status"
  end

  create_table "po_items", force: :cascade do |t|
    t.decimal "actual_material_unit_price", precision: 18, scale: 2
    t.bigint "boq_item_id"
    t.datetime "created_at", null: false
    t.string "item_name", null: false
    t.decimal "labor_unit_price", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "material_unit_price", precision: 18, scale: 2, default: "0.0", null: false
    t.bigint "purchase_order_id", null: false
    t.decimal "quantity", precision: 18, scale: 4, default: "0.0", null: false
    t.decimal "total_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["boq_item_id"], name: "index_po_items_on_boq_item_id"
    t.index ["purchase_order_id", "boq_item_id"], name: "index_po_items_on_purchase_order_id_and_boq_item_id", unique: true
    t.index ["purchase_order_id"], name: "index_po_items_on_purchase_order_id"
    t.check_constraint "quantity > 0::numeric AND material_unit_price >= 0::numeric AND labor_unit_price >= 0::numeric AND (actual_material_unit_price IS NULL OR actual_material_unit_price >= 0::numeric)", name: "po_items_valid_amounts"
  end

  create_table "projects", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "location"
    t.string "name", null: false
    t.string "status", default: "planning", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_projects_on_code", unique: true
    t.check_constraint "status::text = ANY (ARRAY['planning'::character varying, 'active'::character varying, 'completed'::character varying, 'archived'::character varying]::text[])", name: "projects_valid_status"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.text "admin_note"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.boolean "budget_override", default: false, null: false
    t.datetime "created_at", null: false
    t.decimal "grand_total", precision: 18, scale: 2, default: "0.0", null: false
    t.bigint "house_plan_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.date "order_date", null: false
    t.text "override_reason"
    t.string "po_number", null: false
    t.date "procurement_date"
    t.bigint "project_id", null: false
    t.string "pu_number"
    t.string "status", default: "draft", null: false
    t.decimal "total_labor_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "total_material_amount", precision: 18, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.string "vendor_name", null: false
    t.index ["approved_by_id"], name: "index_purchase_orders_on_approved_by_id"
    t.index ["house_plan_id"], name: "index_purchase_orders_on_house_plan_id"
    t.index ["po_number"], name: "index_purchase_orders_on_po_number", unique: true
    t.index ["project_id"], name: "index_purchase_orders_on_project_id"
    t.index ["pu_number"], name: "index_purchase_orders_on_pu_number", unique: true
    t.index ["status", "order_date"], name: "index_purchase_orders_on_status_and_order_date"
    t.check_constraint "status::text <> 'approved'::text OR approved_by_id IS NOT NULL AND approved_at IS NOT NULL", name: "purchase_orders_approval_audit"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'pending_pu'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])", name: "purchase_orders_valid_status"
  end

  create_table "system_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "role::text = ANY (ARRAY['dev'::character varying, 'admin'::character varying, 'project_engineer'::character varying, 'user'::character varying]::text[])", name: "users_valid_role"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "boq_categories", "master_boqs"
  add_foreign_key "boq_items", "boq_categories"
  add_foreign_key "boq_items", "contractors"
  add_foreign_key "house_plans", "projects"
  add_foreign_key "labor_draw_items", "boq_items"
  add_foreign_key "labor_draw_items", "labor_draw_requests"
  add_foreign_key "labor_draw_requests", "contractors"
  add_foreign_key "labor_draw_requests", "house_plans"
  add_foreign_key "labor_draw_requests", "projects"
  add_foreign_key "labor_draw_requests", "users"
  add_foreign_key "labor_draw_requests", "users", column: "approved_by_id"
  add_foreign_key "labor_draw_requests", "users", column: "cancelled_by_id"
  add_foreign_key "login_events", "users"
  add_foreign_key "master_boqs", "house_plans"
  add_foreign_key "po_items", "boq_items"
  add_foreign_key "po_items", "purchase_orders"
  add_foreign_key "purchase_orders", "house_plans"
  add_foreign_key "purchase_orders", "projects"
  add_foreign_key "purchase_orders", "users", column: "approved_by_id"
end
