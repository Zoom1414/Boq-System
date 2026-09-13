class ApproveLaborDrawService < ApproveDocumentService
  private

  def pending_status
    "pending"
  end

  def apply_line!(row, item)
    # Freeze approval-time budget, paid-before-this-draw and remaining snapshots.
    row.save!
    item.update!(labor_paid_amount: item.labor_paid_amount + row.requested_amount)
  end
end
