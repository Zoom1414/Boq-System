module FinancialLineItem
  extend ActiveSupport::Concern

  included do
    belongs_to :boq_item, optional: name == "PoItem"
    validates :quantity, numericality: { greater_than: 0 }
    validate :matches_document_plan
    validate :document_cannot_change, on: :update
    around_save :lock_document_for_change
    before_save :ensure_document_editable
    around_destroy :lock_document_for_change
    before_destroy :ensure_document_editable
    after_save :refresh_document_totals
    after_destroy :refresh_document_totals
  end

  private

  def matches_document_plan
    if boq_item && document && boq_item.master_boq.house_plan_id != document.house_plan_id
      errors.add(:boq_item, "must belong to the selected house plan")
    end
  end

  def document_cannot_change
    if will_save_change_to_attribute?(document_foreign_key)
      errors.add(:base, "Items cannot move between documents")
    end
  end

  # The same parent lock is acquired by approval. A concurrent line edit either
  # commits before approval reads the lines or sees approved and fails.
  def lock_document_for_change
    if document.persisted?
      document.class.transaction do
        @locked_document_for_change = document.class.lock.find(document.id)
        yield
      end
    else
      yield
    end
  ensure
    @locked_document_for_change = nil
  end

  def ensure_document_editable
    if @locked_document_for_change&.approved?
      errors.add(:base, "Approved document items are immutable")
      throw :abort
    end
  end

  def refresh_document_totals
    document.recalculate_totals!
  end
end
