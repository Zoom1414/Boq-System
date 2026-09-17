class CreateDeveloperPanel < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active, :boolean, null: false, default: true

    create_table :login_events do |t|
      t.references :user, foreign_key: true
      t.string :email, null: false
      t.boolean :success, null: false, default: false
      t.string :reason
      t.string :ip_address
      t.string :user_agent
      t.datetime :created_at, null: false
    end
    add_index :login_events, :created_at

    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.text :summary, null: false
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :created_at
    add_index :audit_logs, :action
    add_index :audit_logs, %i[auditable_type auditable_id]

    create_table :system_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :system_settings, :key, unique: true

    add_column :labor_draw_requests, :cancelled_at, :datetime
    add_reference :labor_draw_requests, :cancelled_by, foreign_key: { to_table: :users }
    add_column :labor_draw_requests, :cancel_reason, :text
    remove_check_constraint :labor_draw_requests, name: "labor_draw_requests_valid_status",
      expression: "status::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying]::text[])"
    add_check_constraint :labor_draw_requests, "status IN ('pending', 'approved', 'rejected', 'cancelled')",
      name: "labor_draw_requests_valid_status"
    add_check_constraint :labor_draw_requests, "status <> 'cancelled' OR (cancelled_by_id IS NOT NULL AND cancelled_at IS NOT NULL)",
      name: "labor_draw_requests_cancel_audit"
  end
end
