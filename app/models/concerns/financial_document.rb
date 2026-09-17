module FinancialDocument
  extend ActiveSupport::Concern

  included do
    belongs_to :project
    belongs_to :house_plan
    belongs_to :approved_by, class_name: "User", optional: true

    # Internal service flag. Never permit this or audit/balance fields in controllers.
    attr_accessor :approval_in_progress, :cancellation_in_progress

    validate :project_matches_plan
    validate :valid_approval_transition
    validate :has_line_items
    validate :line_items_match_document
    before_destroy :prevent_approved_destruction, prepend: true
  end

  def budget_warnings
    BudgetCheckService.new(self).warnings
  end

  private

  def project_matches_plan
    if house_plan && house_plan.project_id != project_id
      errors.add(:house_plan, "must belong to the selected project")
    end
  end

  def valid_approval_transition
    if status_in_database == "approved" && changed? && !cancellation_in_progress
      errors.add(:base, "Approved documents are immutable")
    elsif approved? && !approval_in_progress
      errors.add(:status, "must be approved through the approval service")
    end

    if !approval_in_progress && (will_save_change_to_approved_by_id? || will_save_change_to_approved_at? ||
        will_save_change_to_budget_override? || will_save_change_to_override_reason?)
      errors.add(:base, "Approval audit fields are managed by the approval service")
    end
  end

  def has_line_items
    rows = line_items.reject(&:marked_for_destruction?)
    errors.add(:base, "At least one item is required") if rows.empty?
    ids = rows.filter_map(&:boq_item_id)
    if ids.uniq.size != ids.size
      errors.add(:base, "Each BOQ item may appear only once per document")
    end
  end

  def line_items_match_document
    line_items.reject(&:marked_for_destruction?).each do |row|
      next unless row.boq_item

      if row.boq_item.master_boq.house_plan_id != house_plan_id
        errors.add(:base, "All BOQ items must belong to the selected house plan")
      end
      if is_a?(LaborDrawRequest) && !assigned_to?(row.boq_item)
        errors.add(:contractor_name, "must match the contractor assigned to every BOQ item")
      end
    end
  end

  def prevent_approved_destruction
    if approved?
      errors.add(:base, "Approved documents cannot be deleted")
      throw :abort
    end
  end
end
