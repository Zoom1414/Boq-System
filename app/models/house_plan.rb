class HousePlan < ApplicationRecord
  belongs_to :project
  has_one :master_boq, dependent: :restrict_with_error
  has_many :purchase_orders, dependent: :restrict_with_error
  has_many :labor_draw_requests, dependent: :restrict_with_error

  validates :name, :plan_code, presence: true
  validates :plan_code, uniqueness: { scope: :project_id }
  validate :project_cannot_change, on: :update

  private

  def project_cannot_change
    errors.add(:project, "cannot change after creation") if will_save_change_to_project_id?
  end
end
