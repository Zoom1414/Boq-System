require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "document lifecycle and BOQ edits are logged with the acting user" do
    Current.user = @engineer
    draw = build_draw.tap(&:save!)
    assert_equal "dv_create", AuditLog.where(auditable_id: draw.id, auditable_type: "LaborDrawRequest").last.action
    Current.user = @admin
    ApproveLaborDrawService.new(draw, actor: @admin).call
    log = AuditLog.where(action: "dv_approve").last
    assert_equal @admin, log.user
    assert_match draw.dv_number, log.summary

    @item.update!(material_unit_price: 250)
    edit = AuditLog.where(action: "boq_update").last
    assert_equal [ "200.0", "250.0" ], edit.details["material_unit_price"]
    assert_nil edit.details["material_total"]
  end

  test "sensitive fields never reach the log" do
    @contractor.update!(bank_account_number: "9876543210")
    details = AuditLog.where(action: "contractor_update").last.details
    assert_equal "•••3210", details["bank_account_number"].last
    @engineer.update!(password: "another-password-123")
    assert AuditLog.where(action: "user_update").none? { |l| l.details.key?("encrypted_password") }
  end
end
