class ProjectPolicy
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    @user.present?
  end

  alias_method :show?, :index?

  def create?
    @user.present? && (@user.dev? || @user.admin? || @user.project_engineer?)
  end

  alias_method :new?, :create?
  alias_method :edit?, :create?
  alias_method :update?, :create?
  alias_method :destroy?, :create?
end
