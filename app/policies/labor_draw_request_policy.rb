class LaborDrawRequestPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def create?
    (user&.project_engineer? || user&.admin?) && record.user_id == user.id
  end

  def approve?
    user&.admin? == true
  end

  def show?
    user.present?
  end

  alias_method :override_budget?, :approve?
end
