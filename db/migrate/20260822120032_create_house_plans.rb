class CreateHousePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :house_plans do |t|
      t.string :name
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
