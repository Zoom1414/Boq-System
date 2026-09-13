class RejectDocumentService
  def self.call(document, actor:, note:)
    document.with_lock do
      Pundit.authorize(User.find(actor.id), document, :approve?)
      return document if document.rejected?
      expected = document.is_a?(PurchaseOrder) ? "pending_pu" : "pending"
      raise ApproveDocumentService::InvalidState, "เอกสารนี้ไม่อยู่ในสถานะรออนุมัติ" unless document.status == expected
      if note.blank?
        document.errors.add(:admin_note, "กรุณาระบุเหตุผลที่ปฏิเสธ")
        raise ActiveRecord::RecordInvalid, document
      end
      document.update!(status: :rejected, admin_note: note)
      document
    end
  end
end
