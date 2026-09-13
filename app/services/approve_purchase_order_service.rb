class ApprovePurchaseOrderService < ApproveDocumentService
  private

  def pending_status
    "pending_pu"
  end

  def apply_line!(row, item)
    if row.actual_material_unit_price.nil?
      raise InvalidState, "Actual material unit price is required for every PU item (use 0 for labor-only lines)"
    end
    row.save!
    return unless item # Explicit outside-BOQ lines have no master balance to deduct.
    item.update!(material_used_qty: item.material_used_qty + row.quantity,
      labor_paid_amount: item.labor_paid_amount + row.labor_amount)
  end
end
