class LaborDrawRequest < ApplicationRecord
  include Auditable
  include FinancialDocument

  belongs_to :user
  belongs_to :contractor, optional: true
  has_many :labor_draw_items, inverse_of: :labor_draw_request, dependent: :destroy
  accepts_nested_attributes_for :labor_draw_items, allow_destroy: true

  belongs_to :cancelled_by, class_name: "User", optional: true
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", cancelled: "cancelled" }, validate: true

  validates :dv_number, :contractor_name, :request_date, presence: true
  validates :dv_number, uniqueness: true
  validate :requester_can_draw
  validates :submission_key, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/ }, allow_nil: true
  before_validation :link_contractor, on: :create
  before_validation :calculate_total
  validate :payee_bank_account_present, on: :create

  def line_items
    labor_draw_items
  end

  def recalculate_totals!
    updated = update_columns(total_requested_amount: labor_draw_items.sum(:requested_amount), lock_version: lock_version + 1)
    raise ActiveRecord::StaleObjectError.new(self, "update") unless updated
  end

  def assigned_to?(boq_item)
    contractor_id ? boq_item.contractor_id == contractor_id : boq_item.contractor_name == contractor_name
  end

  private

  # Snapshot the contractor's name and bank account at submission so payment history
  # keeps the account actually used, even if the registry is edited later.
  def link_contractor
    if contractor_name.present? && (contractor.nil? || contractor.full_name.casecmp?(contractor_name.squish) == false)
      self.contractor = Contractor.find_by_name(contractor_name)
    end
    return unless contractor

    self.contractor_name = contractor.full_name
    self.payee_bank_name = contractor.bank_name
    self.payee_bank_account_number = contractor.bank_account_number
    self.payee_bank_account_name = contractor.bank_account_name
  end

  def payee_bank_account_present
    if contractor.nil?
      errors.add(:contractor, "ต้องเลือกจากทะเบียนช่าง")
    elsif !contractor.bank_ready?
      errors.add(:base, "ช่าง “#{contractor.full_name}” ยังไม่มีข้อมูลบัญชีธนาคารครบถ้วน ให้ Admin เพิ่มในทะเบียนช่างก่อนเบิก")
    end
  end

  def calculate_total
    self.total_requested_amount = labor_draw_items.reject(&:marked_for_destruction?).sum { |item| item.requested_amount.to_d }
  end

  def requester_can_draw
    if user && !user.project_engineer? && !user.admin? && (new_record? || will_save_change_to_user_id?)
      errors.add(:user, "must be a Project Engineer or Admin")
    end
  end
end
