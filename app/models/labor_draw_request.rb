class LaborDrawRequest < ApplicationRecord
  include FinancialDocument

  belongs_to :user
  has_many :labor_draw_items, inverse_of: :labor_draw_request, dependent: :destroy
  accepts_nested_attributes_for :labor_draw_items, allow_destroy: true

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

  validates :dv_number, :contractor_name, :request_date, presence: true
  validates :dv_number, uniqueness: true
  validate :requester_can_draw
  validates :submission_key, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/ }, allow_nil: true
  before_validation :calculate_total

  def line_items
    labor_draw_items
  end

  def recalculate_totals!
    updated = update_columns(total_requested_amount: labor_draw_items.sum(:requested_amount), lock_version: lock_version + 1)
    raise ActiveRecord::StaleObjectError.new(self, "update") unless updated
  end

  private

  def calculate_total
    self.total_requested_amount = labor_draw_items.reject(&:marked_for_destruction?).sum { |item| item.requested_amount.to_d }
  end

  def requester_can_draw
    if user && !user.project_engineer? && !user.admin? && (new_record? || will_save_change_to_user_id?)
      errors.add(:user, "must be a Project Engineer or Admin")
    end
  end
end
