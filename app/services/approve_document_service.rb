class ApproveDocumentService
  class InvalidState < StandardError; end
  class OverrideReasonRequired < StandardError; end
  class OverrideDisabled < OverrideReasonRequired; end
  class BudgetExceeded < StandardError
    attr_reader :warnings

    def initialize(warnings)
      @warnings = warnings
      super(BudgetCheckService::WARNING)
    end
  end

  def initialize(document, actor:, override: false, override_reason: nil)
    @document = document
    @actor = actor
    @override = override == true
    @override_reason = override_reason
  end

  def call
    @document.class.transaction do
      # Load fresh instances: never approve unsaved/stale caller attributes.
      document = @document.class.lock.find(@document.id)
      actor = User.find(@actor.id) if @actor&.persisted?
      Pundit.authorize(actor, document, :approve?)
      return document if document.approved? # Idempotent retries do not deduct twice.
      raise InvalidState, "Document must be #{pending_status}" unless document.status == pending_status

      rows = document.line_items.reload.to_a
      raise InvalidState, "At least one item is required" if rows.empty?
      # Stable lock ordering prevents deadlocks between multi-item approvals.
      items = BoqItem.where(id: rows.map(&:boq_item_id)).order(:id).lock.index_by(&:id)
      rows.each do |row|
        row.boq_item = items.fetch(row.boq_item_id) if row.boq_item_id
        row.validate!
      end
      document.validate!
      warnings = BudgetCheckService.new(document, boq_items: items).warnings
      raise BudgetExceeded, warnings if warnings.any? && !@override
      if warnings.any? && @override && !SystemSetting.enabled?(:allow_budget_override)
        raise OverrideDisabled, "ระบบปิดการอนุมัติเกินงบไว้ กรุณาปรับยอดให้อยู่ในงบ (ตั้งค่าโดย Developer)"
      end
      if @override
        Pundit.authorize(actor, document, :override_budget?)
        raise OverrideReasonRequired, "An Admin override reason is required" if @override_reason.blank?
      end

      rows.each do |row|
        item = items[row.boq_item_id]
        item.balance_update_in_progress = true if item
        apply_line!(row, item)
      end
      document.approval_in_progress = true
      document.update!(status: :approved, approved_by: actor, approved_at: Time.current,
        budget_override: @override, override_reason: @override ? @override_reason : nil, **approval_attributes)
      document
    end
  end

  private

  def approval_attributes
    {}
  end
end
