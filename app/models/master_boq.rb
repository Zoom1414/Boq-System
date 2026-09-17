class MasterBoq < ApplicationRecord
  include Auditable
  belongs_to :house_plan
  has_many :boq_categories, -> { order(:position, :id) }, dependent: :restrict_with_error
  has_many :boq_items, through: :boq_categories

  enum :status, { draft: "draft", active: "active", archived: "archived" }, validate: true
  validates :house_plan_id, uniqueness: true
  validates :total_material_budget, :total_labor_budget, numericality: { greater_than_or_equal_to: 0 }
  validate :house_plan_cannot_change, on: :update

  # Called in the item's transaction; serialize concurrent budget rollups.
  def recalculate_budgets!
    with_lock do
      update!(total_material_budget: boq_items.sum(:material_total),
        total_labor_budget: boq_items.sum(:labor_total))
    end
  end

  private

  def house_plan_cannot_change
    errors.add(:house_plan, "cannot change after creation") if will_save_change_to_house_plan_id?
  end
end
