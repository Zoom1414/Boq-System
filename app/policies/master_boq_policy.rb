class MasterBoqPolicy < ProjectPolicy
  # Everyone signed in can read and export; only Admin may change the Master BOQ
  # (create it, edit categories/items inline or in the dialog, and import CSV).
  def create?
    @user&.admin? == true
  end

  alias_method :new?, :create?
  alias_method :edit?, :create?
  alias_method :update?, :create?
  alias_method :destroy?, :create?
  alias_method :import?, :create?
  alias_method :export?, :show?
  alias_method :backup?, :show?
end
