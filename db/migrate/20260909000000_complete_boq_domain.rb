class CompleteBoqDomain < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :code, :string
    add_column :projects, :location, :string
    add_column :projects, :status, :string, null: false, default: "planning"
    add_column :house_plans, :plan_code, :string

    # Preserve existing scaffold data and give legacy rows unique identifiers.
    reversible do |dir|
      dir.up do
        execute "UPDATE projects SET code = 'LEGACY-P-' || id"
        execute "UPDATE house_plans SET plan_code = 'LEGACY-HP-' || id"
        execute "UPDATE projects SET name = 'Unnamed project' WHERE name IS NULL"
        execute "UPDATE house_plans SET name = 'Unnamed plan' WHERE name IS NULL"
      end
    end
    change_column_null :projects, :name, false
    change_column_null :projects, :code, false
    change_column_null :house_plans, :name, false
    change_column_null :house_plans, :plan_code, false
    add_index :projects, :code, unique: true
    add_index :house_plans, [ :project_id, :plan_code ], unique: true

    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :role, null: false, default: "user"
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true

    create_table :master_boqs do |t|
      t.references :house_plan, null: false, foreign_key: true, index: { unique: true }
      money t, :total_material_budget, :total_labor_budget
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    create_table :boq_categories do |t|
      t.references :master_boq, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :boq_categories, [ :master_boq_id, :position ]

    create_table :boq_items do |t|
      t.references :boq_category, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :unit, null: false
      quantity t, :material_quantity, :material_used_qty, :material_remaining_qty
      money t, :material_unit_price, :material_total, :labor_unit_price,
        :labor_total, :labor_paid_amount, :labor_remaining_amount
      t.decimal :progress_percentage, precision: 5, scale: 2, null: false, default: 0
      t.string :contractor_name
      t.text :note
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :boq_items, [ :boq_category_id, :code ], unique: true
    add_index :boq_items, :contractor_name

    create_table :purchase_orders do |t|
      t.string :po_number, null: false
      t.references :project, null: false, foreign_key: true
      t.references :house_plan, null: false, foreign_key: true
      t.string :vendor_name, null: false
      t.date :order_date, null: false
      t.string :status, null: false, default: "draft"
      money t, :total_material_amount, :total_labor_amount, :grand_total
      approval_fields t
      t.timestamps
    end
    add_index :purchase_orders, :po_number, unique: true
    add_index :purchase_orders, [ :status, :order_date ]

    create_table :po_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :boq_item, null: false, foreign_key: true
      t.string :item_name, null: false
      quantity t, :quantity
      money t, :material_unit_price, :labor_unit_price, :total_amount
      t.decimal :actual_material_unit_price, precision: 18, scale: 2
      t.timestamps
    end
    add_index :po_items, [ :purchase_order_id, :boq_item_id ], unique: true

    create_table :labor_draw_requests do |t|
      t.string :dv_number, null: false
      t.references :project, null: false, foreign_key: true
      t.references :house_plan, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :contractor_name, null: false
      t.date :request_date, null: false
      t.string :status, null: false, default: "pending"
      money t, :total_requested_amount
      t.text :admin_note
      approval_fields t
      t.timestamps
    end
    add_index :labor_draw_requests, :dv_number, unique: true
    add_index :labor_draw_requests, [ :status, :request_date ]

    create_table :labor_draw_items do |t|
      t.references :labor_draw_request, null: false, foreign_key: true
      t.references :boq_item, null: false, foreign_key: true
      t.string :work_description, null: false
      quantity t, :quantity
      money t, :unit_price, :budget_total, :paid_amount, :requested_amount, :remaining_amount
      t.timestamps
    end
    add_index :labor_draw_items, [ :labor_draw_request_id, :boq_item_id ], unique: true

    {
      users: [ :role, %w[dev admin project_engineer user] ],
      projects: [ :status, %w[planning active completed archived] ],
      master_boqs: [ :status, %w[draft active archived] ],
      purchase_orders: [ :status, %w[draft pending_pu approved rejected] ],
      labor_draw_requests: [ :status, %w[pending approved rejected] ]
    }.each do |table, (column, values)|
      add_check_constraint table, "#{column} IN (#{values.map { |v| "'#{v}'" }.join(', ')})",
        name: "#{table}_valid_#{column}"
    end
    add_check_constraint :boq_items,
      "material_quantity >= 0 AND material_used_qty >= 0 AND material_unit_price >= 0 AND labor_unit_price >= 0 AND labor_paid_amount >= 0 AND progress_percentage BETWEEN 0 AND 100",
      name: "boq_items_nonnegative_inputs"
    add_check_constraint :po_items,
      "quantity > 0 AND material_unit_price >= 0 AND labor_unit_price >= 0 AND (actual_material_unit_price IS NULL OR actual_material_unit_price >= 0)",
      name: "po_items_valid_amounts"
    add_check_constraint :labor_draw_items, "quantity > 0 AND unit_price >= 0 AND requested_amount > 0",
      name: "labor_draw_items_valid_amounts"
    # Remaining values may be negative after an explicit Admin override.
    [ :purchase_orders, :labor_draw_requests ].each do |table|
      add_check_constraint table,
        "status <> 'approved' OR (approved_by_id IS NOT NULL AND approved_at IS NOT NULL)",
        name: "#{table}_approval_audit"
    end
  end

  private

  def money(table, *columns)
    columns.each { |column| table.decimal column, precision: 18, scale: 2, null: false, default: 0 }
  end

  def quantity(table, *columns)
    columns.each { |column| table.decimal column, precision: 18, scale: 4, null: false, default: 0 }
  end

  def approval_fields(table)
    table.references :approved_by, foreign_key: { to_table: :users }
    table.datetime :approved_at
    table.boolean :budget_override, null: false, default: false
    table.text :override_reason
    table.integer :lock_version, null: false, default: 0
  end
end
