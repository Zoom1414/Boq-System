class LaborDrawItem < ApplicationRecord
  include FinancialLineItem
  belongs_to :labor_draw_request, inverse_of: :labor_draw_items

  validates :work_description, presence: true
  validates :boq_item_id, uniqueness: { scope: :labor_draw_request_id }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :requested_amount, numericality: { greater_than: 0 }
  validate :contractor_matches_item
  before_validation :snapshot_budget

  # requested_amount is an explicit installment, not necessarily quantity * rate.
  def snapshot_budget
    return unless boq_item

    self.budget_total = boq_item.labor_total
    self.paid_amount = boq_item.labor_paid_amount
    self.remaining_amount = budget_total - paid_amount - requested_amount.to_d
  end

  private

  def document
    labor_draw_request
  end

  def document_foreign_key
    :labor_draw_request_id
  end

  def contractor_matches_item
    if boq_item && labor_draw_request && !labor_draw_request.assigned_to?(boq_item)
      errors.add(:boq_item, "must be assigned to the selected contractor")
    end
  end
end
