class MasterBoqPolicy < ProjectPolicy
  alias_method :export?, :show?
  alias_method :backup?, :show?
  alias_method :import?, :create?
end
