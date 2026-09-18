class User < ApplicationRecord
  include Auditable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { dev: "dev", admin: "admin", project_engineer: "project_engineer", user: "user" }, validate: true

  has_many :labor_draw_requests, dependent: :restrict_with_error
  has_many :approved_labor_draw_requests, class_name: "LaborDrawRequest", foreign_key: :approved_by_id, dependent: :restrict_with_error
  has_many :approved_purchase_orders, class_name: "PurchaseOrder", foreign_key: :approved_by_id, dependent: :restrict_with_error

  has_many :login_events, dependent: :nullify
  has_many :audit_logs, dependent: :nullify

  validates :name, presence: true

  ROLE_LABELS = { "dev" => "ผู้พัฒนา", "admin" => "ผู้ดูแลระบบ", "project_engineer" => "วิศวกรโครงการ", "user" => "ผู้ใช้งาน" }.freeze

  # Deactivated accounts cannot sign in (Devise checks this on every request).
  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive
  end
end
