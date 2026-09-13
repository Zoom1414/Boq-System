class PurchaseOrderPolicy
  def initialize(user, record)
    @user = user
    @record = record
  end

  def create?
    @user&.admin? || @user&.project_engineer?
  end

  def show?
    @user.present?
  end

  def approve?
    @user&.admin? == true
  end

  alias_method :override_budget?, :approve?
end
