class PurchaseOrder < ApplicationRecord
  include Auditable
  include FinancialDocument

  has_many :po_items, inverse_of: :purchase_order, dependent: :destroy
  accepts_nested_attributes_for :po_items, allow_destroy: true

  enum :status, { draft: "draft", pending_pu: "pending_pu", approved: "approved", rejected: "rejected" }, validate: true

  validates :po_number, :vendor_name, :order_date, presence: true
  validates :po_number, uniqueness: true
  before_validation :calculate_totals

  def line_items
    po_items
  end

  def recalculate_totals!
    rows = PoItem.where(purchase_order_id: id).to_a
    updated = update_columns(total_material_amount: rows.sum(&:material_amount),
      total_labor_amount: rows.sum(&:labor_amount), grand_total: rows.sum(&:total_amount),
      lock_version: lock_version + 1)
    raise ActiveRecord::StaleObjectError.new(self, "update") unless updated
  end

  private

  def calculate_totals
    rows = po_items.reject(&:marked_for_destruction?)
    self.total_material_amount = rows.sum(&:material_amount)
    self.total_labor_amount = rows.sum(&:labor_amount)
    self.grand_total = total_material_amount + total_labor_amount
  end
end
