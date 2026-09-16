class AddLaborSubmissionKey < ActiveRecord::Migration[8.1]
  def change
    add_column :labor_draw_requests, :submission_key, :string
    add_index :labor_draw_requests, :submission_key, unique: true
  end
end
