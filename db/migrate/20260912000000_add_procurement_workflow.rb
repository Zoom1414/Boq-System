class AddProcurementWorkflow < ActiveRecord::Migration[8.1]
  def change
    add_column :purchase_orders, :pu_number, :string
    add_column :purchase_orders, :procurement_date, :date
    add_column :purchase_orders, :admin_note, :text
    add_index :purchase_orders, :pu_number, unique: true
    change_column_null :po_items, :boq_item_id, true
    add_column :po_items, :unit, :string
    create_table :document_sequences do |t|
      t.string :name, null: false
      t.bigint :value, default: 0, null: false
      t.index :name, unique: true
    end
  end
end
