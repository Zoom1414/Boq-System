class CreateContractors < ActiveRecord::Migration[8.1]
  def up
    create_table :contractors do |t|
      t.string :first_name, null: false
      t.string :last_name
      t.string :full_name, null: false
      t.string :trade
      t.string :phone
      t.string :bank_name
      t.string :bank_account_number
      t.string :bank_account_name
      t.text :note
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :contractors, "lower(full_name)", unique: true, name: "index_contractors_on_lower_full_name"
    # One bank account may belong to only one contractor (duplicate-payee guard).
    add_index :contractors, :bank_account_number, unique: true, where: "bank_account_number IS NOT NULL"
    add_index :contractors, :trade
    add_check_constraint :contractors, "bank_account_number IS NULL OR bank_account_number ~ '^[0-9]{10,15}$'",
      name: "contractors_bank_account_digits"

    add_reference :boq_items, :contractor, foreign_key: true
    add_reference :labor_draw_requests, :contractor, foreign_key: true
    add_column :labor_draw_requests, :payee_bank_name, :string
    add_column :labor_draw_requests, :payee_bank_account_number, :string
    add_column :labor_draw_requests, :payee_bank_account_name, :string

    # Register every contractor name already used in BOQ items and DVs, then link them.
    execute <<~SQL
      INSERT INTO contractors (first_name, full_name, created_at, updated_at)
      SELECT DISTINCT ON (lower(name)) name, name, NOW(), NOW()
      FROM (
        SELECT regexp_replace(btrim(contractor_name), '\\s+', ' ', 'g') AS name FROM boq_items
        UNION ALL
        SELECT regexp_replace(btrim(contractor_name), '\\s+', ' ', 'g') FROM labor_draw_requests
      ) names
      WHERE name IS NOT NULL AND name <> ''
      ORDER BY lower(name), name;
    SQL
    %w[boq_items labor_draw_requests].each do |table|
      execute <<~SQL
        UPDATE #{table} SET contractor_id = contractors.id
        FROM contractors
        WHERE lower(regexp_replace(btrim(#{table}.contractor_name), '\\s+', ' ', 'g')) = lower(contractors.full_name);
      SQL
    end
  end

  def down
    remove_column :labor_draw_requests, :payee_bank_account_name
    remove_column :labor_draw_requests, :payee_bank_account_number
    remove_column :labor_draw_requests, :payee_bank_name
    remove_reference :labor_draw_requests, :contractor, foreign_key: true
    remove_reference :boq_items, :contractor, foreign_key: true
    drop_table :contractors
  end
end
