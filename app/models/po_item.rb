class PoItem < ApplicationRecord
  include FinancialLineItem
  belongs_to :purchase_order, inverse_of: :po_items

  validates :item_name, presence: true
  validates :boq_item_id, uniqueness: { scope: :purchase_order_id }, allow_nil: true
  validates :material_unit_price, :labor_unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :actual_material_unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  before_validation :calculate_total

  def material_amount
    (quantity.to_d * (actual_material_unit_price || material_unit_price).to_d).round(2)
  end

  def labor_amount
    (quantity.to_d * labor_unit_price.to_d).round(2)
  end

  private

  def calculate_total
    self.total_amount = material_amount + labor_amount
  end

  def document
    purchase_order
  end

  def document_foreign_key
    :purchase_order_id
  end
end
