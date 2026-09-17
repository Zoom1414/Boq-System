class BoqItem < ApplicationRecord
  belongs_to :boq_category
  belongs_to :contractor, optional: true
  has_one :master_boq, through: :boq_category
  has_many :po_items, dependent: :restrict_with_error
  has_many :labor_draw_items, dependent: :restrict_with_error

  attr_accessor :balance_update_in_progress

  before_validation :calculate_totals
  before_validation :sync_contractor
  after_save :refresh_master_budget, if: :budget_changed?
  after_destroy :refresh_master_budget

  validates :code, :name, :unit, presence: true
  validates :code, uniqueness: { scope: :boq_category_id }
  validates :material_quantity, :material_unit_price, :labor_unit_price,
    :material_used_qty, :labor_paid_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :progress_percentage, numericality: { in: 0..100 }
  validate :category_cannot_change, on: :update
  validate :balances_are_service_managed

  def pending_labor_amount
    labor_draw_items.joins(:labor_draw_request)
      .where(labor_draw_requests: { status: "pending" }).sum(:requested_amount) +
      po_items.joins(:purchase_order).where(purchase_orders: { status: "pending_pu" })
        .sum("ROUND(po_items.quantity * po_items.labor_unit_price, 2)")
  end

  # % complete = materials used ÷ BOQ quantity. Labor-only rows (no quantity) use labor paid ÷ labor budget.
  def completion_percentage
    ratio = if material_quantity.to_d.positive?
      material_used_qty.to_d / material_quantity.to_d
    elsif labor_total.to_d.positive?
      labor_paid_amount.to_d / labor_total.to_d
    else
      0
    end
    (ratio * 100).round(1)
  end

  def capped_completion
    completion_percentage.clamp(0, 100)
  end

  def completed?
    completion_percentage >= 100
  end

  def pending_material_quantity
    po_items.joins(:purchase_order).where(purchase_orders: { status: "pending_pu" }).sum(:quantity)
  end

  private

  # contractor_id is the source of truth; contractor_name is kept as a readable snapshot
  # (CSV import / legacy data may supply only a name, which is linked to the registry).
  def sync_contractor
    if will_save_change_to_contractor_id?
      self.contractor_name = contractor&.full_name
    elsif will_save_change_to_contractor_name?
      self.contractor = contractor_name.to_s.squish.presence && Contractor.resolve_name!(contractor_name)
      self.contractor_name = contractor&.full_name
    end
  end

  def calculate_totals
    self.material_total = (material_quantity.to_d * material_unit_price.to_d).round(2)
    self.labor_total = (material_quantity.to_d * labor_unit_price.to_d).round(2)
    self.material_remaining_qty = material_quantity.to_d - material_used_qty.to_d
    self.labor_remaining_amount = labor_total - labor_paid_amount.to_d
  end

  def budget_changed?
    saved_change_to_material_total? || saved_change_to_labor_total?
  end

  def refresh_master_budget
    master_boq.recalculate_budgets!
  end

  def category_cannot_change
    errors.add(:boq_category, "cannot change after creation") if will_save_change_to_boq_category_id?
  end

  def balances_are_service_managed
    return if balance_update_in_progress
    return if new_record? && material_used_qty.to_d.zero? && labor_paid_amount.to_d.zero?

    if will_save_change_to_material_used_qty? || will_save_change_to_labor_paid_amount?
      errors.add(:base, "Balances must be updated through an approval service")
    end
  end
end
