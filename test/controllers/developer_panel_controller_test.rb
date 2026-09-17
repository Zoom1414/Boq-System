require "test_helper"

class DeveloperPanelControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    setup_boq
    @dev = User.create!(name: "Dev", email: "dev@example.test", password: "test-password-123", role: :dev)
  end

  test "only developers can open the panel" do
    [ @admin, @engineer ].each do |user|
      sign_in user
      get developer_path
      assert_response :forbidden
    end
    sign_in @dev
    [ developer_path, developer_users_path, developer_projects_path, developer_logins_path, developer_audit_path,
      developer_permissions_path, developer_approvals_path, developer_cancellations_path, developer_notifications_path,
      developer_system_path ].each do |path|
      get path
      assert_response :success, path
      assert_select ".dp-tabs .dp-tab.is-active"
    end
    get developer_export_path("audit")
    assert_response :success
    assert_includes response.body, "summary"
  end

  test "developer creates, updates and deactivates users" do
    sign_in @dev
    assert_difference "User.count", 1 do
      post developer_users_path, params: { user: { name: "New", email: "new@example.test", role: "admin", password: "long-password-123" } }
    end
    user = User.find_by!(email: "new@example.test")
    assert user.admin?
    patch developer_user_path(user), params: { user: { role: "user", active: "0", password: "" } }
    assert user.reload.user?
    assert_not user.active?
    assert_not user.active_for_authentication?
    post developer_users_path, params: { user: { name: "Short", email: "short@example.test", role: "user", password: "short" } }
    assert_response :unprocessable_entity
    patch developer_user_path(@dev), params: { user: { role: "user" } }
    assert @dev.reload.dev?
  end

  test "cancelling an approved DV returns labor to the BOQ and is audited" do
    draw = build_draw.tap(&:save!)
    ApproveLaborDrawService.new(draw, actor: @admin).call
    assert_equal 400, @item.reload.labor_paid_amount
    sign_in @dev
    patch developer_cancel_draw_path(draw), params: { cancel_reason: "" }
    assert draw.reload.approved?
    patch developer_cancel_draw_path(draw), params: { cancel_reason: "บันทึกซ้ำ" }
    assert draw.reload.cancelled?
    assert_equal @dev, draw.cancelled_by
    assert_equal 0, @item.reload.labor_paid_amount
    assert AuditLog.exists?(action: "dv_cancel", auditable_id: draw.id)
    sign_in @admin
    patch developer_cancel_draw_path(build_draw.tap(&:save!)), params: { cancel_reason: "x" }
    assert_response :forbidden
  end

  test "settings control approvals, projects, announcements and maintenance" do
    sign_in @dev
    patch developer_approvals_path, params: { settings: { allow_budget_override: "false", admin_instant_labor_approval: "false", engineer_can_manage_projects: "false" } }
    assert_not SystemSetting.enabled?(:allow_budget_override)
    assert_raises(ApproveDocumentService::OverrideDisabled) do
      ApproveLaborDrawService.new(build_draw(amount: 1500).tap(&:save!), actor: @admin, override: true, override_reason: "extra").call
    end
    assert_not ProjectPolicy.new(@engineer, Project).create?
    assert SubmitLaborDrawService.new(LaborDrawRequest.new(dv_number: "DV-X", project: @project, house_plan: @plan, contractor_name: "Team A",
      request_date: Date.current, user: @admin, labor_draw_items_attributes: [ { boq_item: @item, work_description: "x", quantity: 1, unit_price: 1, requested_amount: 10 } ]),
      actor: @admin).call.pending?

    patch developer_notifications_path, params: { settings: { announcement_active: "true", announcement_level: "warning", announcement_message: "ปิดรับ DV 17:00" } }
    patch developer_system_path, params: { settings: { maintenance_mode: "true", maintenance_message: "ปรับปรุง" } }
    sign_in @engineer
    get dashboard_path
    assert_response :service_unavailable
    assert_select "h1", text: /ปิดปรับปรุง/
    sign_in @admin
    get dashboard_path
    assert_response :success
    assert_select ".dp-announcement.is-warning", text: /ปิดรับ DV/
    assert AuditLog.where(action: "setting_update").count >= 5
  end

  test "sign-ins are recorded" do
    post user_session_path, params: { user: { email: @engineer.email, password: "wrong-password-123" } }
    post user_session_path, params: { user: { email: @engineer.email, password: "test-password-123" } }
    assert LoginEvent.exists?(email: @engineer.email, success: false)
    assert LoginEvent.exists?(user: @engineer, success: true)
  end
end
