class ContractorPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  alias_method :show?, :index?

  # Only Admin maintains the registry and sees full bank account numbers.
  def create?
    user&.admin? == true
  end

  alias_method :new?, :create?
  alias_method :edit?, :create?
  alias_method :update?, :create?
  alias_method :view_bank_account?, :create?
end
