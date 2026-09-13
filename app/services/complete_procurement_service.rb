class CompleteProcurementService
  def initialize(order, actor:, attributes:, override: false, override_reason: nil)
    @order, @actor, @attributes = order, actor, attributes
    @override, @override_reason = override, override_reason
  end

  def call
    @order.with_lock do
      Pundit.authorize(User.find(@actor.id), @order, :approve?)
      return @order if @order.approved?
      raise ApproveDocumentService::InvalidState, "เอกสารไม่ได้อยู่ในสถานะรอจัดซื้อ" unless @order.pending_pu?

      @order.assign_attributes(@attributes)
      if @order.procurement_date.blank?
        @order.errors.add(:procurement_date, "กรุณาระบุวันที่ซื้อ/จ้างจริง")
        raise ActiveRecord::RecordInvalid, @order
      end
      @order.pu_number ||= DocumentSequence.next_number("PU")
      @order.save!
      ApprovePurchaseOrderService.new(@order, actor: @actor, override: @override, override_reason: @override_reason).call
    end
  end
end
