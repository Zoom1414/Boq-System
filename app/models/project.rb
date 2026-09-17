class Project < ApplicationRecord
  include Auditable
  has_many :house_plans, dependent: :restrict_with_error
  has_many :purchase_orders, dependent: :restrict_with_error
  has_many :labor_draw_requests, dependent: :restrict_with_error

  enum :status, { planning: "planning", active: "active", completed: "completed", archived: "archived" }, validate: true

  validates :name, :code, presence: true
  validates :code, uniqueness: true
end
