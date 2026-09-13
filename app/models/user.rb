class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { dev: "dev", admin: "admin", project_engineer: "project_engineer", user: "user" }, validate: true

  has_many :labor_draw_requests, dependent: :restrict_with_error
  has_many :approved_labor_draw_requests, class_name: "LaborDrawRequest", foreign_key: :approved_by_id, dependent: :restrict_with_error
  has_many :approved_purchase_orders, class_name: "PurchaseOrder", foreign_key: :approved_by_id, dependent: :restrict_with_error

  validates :name, presence: true
end
