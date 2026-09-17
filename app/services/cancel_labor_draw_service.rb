# Developer-only: cancel a pending DV, or reverse an approved DV (returns the paid labor to the BOQ).
class CancelLaborDrawService
  class InvalidState < StandardError; end

  def initialize(draw, actor:, reason:)
    @draw, @actor, @reason = draw, actor, reason.to_s.strip
  end

  def call
    raise InvalidState, "กรุณาระบุเหตุผลการยกเลิก" if @reason.blank?

    LaborDrawRequest.transaction do
      draw = LaborDrawRequest.lock.find(@draw.id)
      actor = User.find(@actor.id)
      raise Pundit::NotAuthorizedError unless actor.dev?
      return draw if draw.cancelled?
      raise InvalidState, "ยกเลิกได้เฉพาะใบเบิกที่รออนุมัติหรืออนุมัติแล้ว" unless draw.pending? || draw.approved?

      if draw.approved?
        rows = draw.labor_draw_items.to_a
        items = BoqItem.where(id: rows.map(&:boq_item_id)).order(:id).lock.index_by(&:id)
        rows.each do |row|
          item = items.fetch(row.boq_item_id)
          item.balance_update_in_progress = true
          item.update!(labor_paid_amount: [ item.labor_paid_amount - row.requested_amount, 0 ].max)
        end
      end
      draw.cancellation_in_progress = true
      draw.update!(status: :cancelled, cancelled_at: Time.current, cancelled_by: actor, cancel_reason: @reason)
      draw
    end
  end
end
