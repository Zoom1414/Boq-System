class BoqCategory < ApplicationRecord
  include Auditable
  belongs_to :master_boq
  has_many :boq_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :master_cannot_change, on: :update

  private

  def master_cannot_change
    errors.add(:master_boq, "cannot change after creation") if will_save_change_to_master_boq_id?
  end
end
