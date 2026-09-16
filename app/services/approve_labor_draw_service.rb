class ApproveLaborDrawService < ApproveDocumentService
  def initialize(document, admin_note: nil, **options)
    super(document, **options)
    @admin_note = admin_note
  end

  private

  def approval_attributes
    @admin_note.nil? ? {} : { admin_note: @admin_note }
  end

  def pending_status
    "pending"
  end

  def apply_line!(row, item)
    # Freeze approval-time budget, paid-before-this-draw and remaining snapshots.
    row.save!
    item.update!(labor_paid_amount: item.labor_paid_amount + row.requested_amount)
  end
end
