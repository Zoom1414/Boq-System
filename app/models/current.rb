# Per-request state: who is acting (for audit logs) and cached system settings.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :settings
end
