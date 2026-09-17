# Writes an AuditLog row after every committed create/update/destroy.
module Auditable
  extend ActiveSupport::Concern

  included do
    after_create_commit { AuditLog.capture(self, "create") }
    after_update_commit { AuditLog.capture(self, "update") }
    after_destroy_commit { AuditLog.capture(self, "destroy") }
  end
end
