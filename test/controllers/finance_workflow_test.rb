require "test_helper"

class FinanceWorkflowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    setup_boq
    sign_in @engineer
    @context = { project_id: @project.id, house_plan_id: @plan.id }
  end

  test "finance pages share the workspace and render empty and populated states" do
    [ dashboard_path, new_purchase_order_path, purchase_orders_path, pending_purchase_orders_path,
      history_purchase_orders_path, new_labor_draw_request_path, labor_draw_requests_path, approvals_path ].each do |path|
      get path, params: @context
      assert_response :success
      assert_select ".workspace-shell"
    end
    po = create_po
    draw = build_draw.tap(&:save!)
    [ purchase_order_path(po), labor_draw_request_path(draw), purchase_orders_path, pending_purchase_orders_path,
      labor_draw_requests_path, approvals_path, dashboard_path ].each do |path|
      get path, params: @context
      assert_response :success
    end
    sign_in @admin
    get procure_purchase_order_path(po), headers: { "Turbo-Frame" => "boq_editor" }
    assert_response :success
    assert_select "turbo-frame#boq_editor dialog"
  end

  test "PO creation derives BOQ labels and sends Turbo budget warning without deductions" do
    assert_difference "PurchaseOrder.count", 1 do
      post purchase_orders_path, params: po_params(quantity: 11), as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[target='budget_warnings']", text: /exceeds the Master BOQ/
    order = PurchaseOrder.order(:id).last
    assert order.pending_pu?
    assert_match(/\APO-\d{4}-\d+\z/, order.po_number)
    assert_equal @item.name, order.po_items.first.item_name
    assert_nil order.po_items.first.actual_material_unit_price
    assert_equal 0, @item.reload.material_used_qty
    assert_equal 0, @item.labor_paid_amount
  end

  test "PO supports multiple outside BOQ items and real PU approval is atomic and idempotent" do
    data = po_params
    data[:purchase_order][:po_items_attributes]["1"] = { item_name: "Extra delivery", unit: "trip", quantity: 1, material_unit_price: 50, labor_unit_price: 0 }
    data[:purchase_order][:po_items_attributes]["2"] = { item_name: "Extra setup", unit: "job", quantity: 1, material_unit_price: 0, labor_unit_price: 30 }
    post purchase_orders_path, params: data
    assert_response :redirect
    order = PurchaseOrder.order(:id).last
    assert_equal 3, order.po_items.size
    sign_in @admin
    prices = order.po_items.each_with_index.to_h { |row, index| [ index.to_s, { id: row.id, actual_material_unit_price: row.material_unit_price } ] }
    prices["0"][:actual_material_unit_price] = 250
    patch complete_purchase_order_path(order), params: { purchase_order: { procurement_date: Date.current, po_items_attributes: prices } }
    assert_response :redirect
    assert order.reload.approved?
    assert_match(/\APU-\d{4}-\d+\z/, order.pu_number)
    assert_equal 780, order.grand_total
    assert_equal 2, @item.reload.material_used_qty
    assert_equal 200, @item.labor_paid_amount
    patch complete_purchase_order_path(order), params: { purchase_order: { procurement_date: Date.current, po_items_attributes: prices } }
    assert_response :redirect
    assert_equal 2, @item.reload.material_used_qty
    get history_purchase_orders_path, params: @context
    assert_response :success
    assert_includes response.body, order.pu_number
    get dashboard_path, params: @context
    assert_response :success
    assert_select ".dashboard-stat", text: /ค่าวัสดุที่อนุมัติ.*550.00/m
    assert_select ".dashboard-stat", text: /ค่าแรงที่อนุมัติ.*230.00/m
  end

  test "failed PU approval rolls back actual prices and receipt metadata then allows explicit override" do
    order = create_po(quantity: 11, actual_price: nil)
    sign_in @admin
    data = { purchase_order: { procurement_date: Date.current, po_items_attributes: { "0" => { id: order.po_items.first.id, actual_material_unit_price: 500 } } } }
    patch complete_purchase_order_path(order), params: data
    assert_response :unprocessable_entity
    assert order.reload.pending_pu?
    assert_nil order.pu_number
    assert_nil order.po_items.first.actual_material_unit_price
    assert_equal 0, @item.reload.material_used_qty
    patch complete_purchase_order_path(order), params: data.merge(budget_override: "1", override_reason: "Additional approved scope")
    assert_response :redirect
    assert order.reload.approved?
    assert_equal(-1, @item.reload.material_remaining_qty)
  end

  test "DV derives requester rates and snapshots and only Admin approval deducts budget" do
    post labor_draw_requests_path, params: draw_params, as: :turbo_stream
    assert_response :success
    draw = LaborDrawRequest.order(:id).last
    assert_equal @engineer.id, draw.user_id
    assert_equal 100, draw.labor_draw_items.first.unit_price
    assert_equal 0, @item.reload.labor_paid_amount
    patch approve_labor_draw_request_path(draw)
    assert_response :forbidden
    sign_in @admin
    patch approve_labor_draw_request_path(draw)
    assert_response :redirect
    assert_equal 400, @item.reload.labor_paid_amount
    patch approve_labor_draw_request_path(draw)
    assert_equal 400, @item.reload.labor_paid_amount
    get labor_draw_requests_path, params: @context
    assert_response :success
    assert_select ".month-card", count: 1
    assert_select ".labor-hero", text: /400.00/
  end

  test "contractor item frame filters items and invalid empty DV is redisplayed" do
    create_boq_item("OTHER").update!(contractor_name: "Team B")
    get new_labor_draw_request_path, params: @context.merge(contractor_name: "Team B"), headers: { "Turbo-Frame" => "labor-items" }
    assert_response :success
    assert_select "turbo-frame#labor-items", text: /OTHER/
    assert_select ".labor-entry", text: /CONCRETE/, count: 0
    data = draw_params
    data[:labor_draw_request][:labor_draw_items_attributes]["0"][:requested_amount] = 0
    assert_no_difference "LaborDrawRequest.count" do
      post labor_draw_requests_path, params: data, as: :turbo_stream
      assert_response :unprocessable_entity
    end
  end

  test "rejection requires a reason and never deducts or reverses an approved document" do
    draw = build_draw.tap(&:save!)
    sign_in @admin
    patch reject_labor_draw_request_path(draw), params: { admin_note: "" }
    assert draw.reload.pending?
    patch reject_labor_draw_request_path(draw), params: { admin_note: "Work incomplete" }
    assert draw.reload.rejected?
    assert_equal "Work incomplete", draw.admin_note
    assert_equal 0, @item.reload.labor_paid_amount
    po = create_po
    ApprovePurchaseOrderService.new(po, actor: @admin).call
    patch reject_purchase_order_path(po), params: { admin_note: "Cannot reverse" }
    assert po.reload.approved?
  end

  test "read-only users cannot submit finance records and engineers cannot approve procurement" do
    order = create_po
    patch complete_purchase_order_path(order), params: { purchase_order: { procurement_date: Date.current } }
    assert_response :forbidden
    @engineer.update!(role: :user)
    sign_in @engineer
    assert_no_difference "PurchaseOrder.count" do
      post purchase_orders_path, params: po_params
      assert_response :forbidden
    end
    post labor_draw_requests_path, params: draw_params
    assert_response :forbidden
  end

  test "cross-plan and wrong-contractor line submissions are rejected" do
    data = po_params
    data[:purchase_order].merge!(project_id: house_plans(:two).project_id, house_plan_id: house_plans(:two).id)
    assert_no_difference "PurchaseOrder.count" do
      post purchase_orders_path, params: data
      assert_response :not_found
    end
    sign_in @engineer
    data = draw_params
    data[:labor_draw_request][:contractor_name] = "Wrong team"
    assert_no_difference "LaborDrawRequest.count" do
      post labor_draw_requests_path, params: data
      assert_response :not_found
    end
  end

  test "sidebar targets persistent workspace frame with history and rendered active-page metadata" do
    [ [ dashboard_path, dashboard_path ], [ new_labor_draw_request_path, new_labor_draw_request_path ],
      [ master_boq_path, master_boq_path ], [ approvals_path, approvals_path ] ].each do |path, active|
      get path, params: @context, headers: { "Turbo-Frame" => "workspace_content" }
      assert_response :success
      assert_select "turbo-frame#workspace_content[data-turbo-action='advance']"
      assert_select "turbo-frame#workspace_content [data-workspace-page='#{active}']"
      assert_select ".workspace-nav-link[data-turbo-frame='workspace_content']"
    end
  end

  test "Admin submits and approves a labor draw in one action and retry never deducts twice" do
    sign_in @admin
    get new_labor_draw_request_path, params: @context
    assert_response :success
    assert_select "input[type='submit'][value='บันทึกเบิกค่าแรงทันที']"
    assert_select ".labor-entry input[type='number'][disabled]", count: 0
    data = draw_params
    data[:labor_draw_request][:submission_key] = SecureRandom.uuid
    assert_difference "LaborDrawRequest.count", 1 do
      post labor_draw_requests_path, params: data, as: :turbo_stream
      assert_response :success
      assert_select ".finance-success", text: /อนุมัติและหักยอด BOQ แล้ว/
    end
    draw = LaborDrawRequest.last
    assert draw.approved?
    assert_equal @admin.id, draw.user_id
    assert_equal @admin.id, draw.approved_by_id
    assert_equal 400, @item.reload.labor_paid_amount
    assert_no_difference "LaborDrawRequest.count" do
      post labor_draw_requests_path, params: data, as: :turbo_stream
      assert_response :success
    end
    assert_equal 400, @item.reload.labor_paid_amount
  end

  test "Admin immediate over-budget draw rolls back completely and can retry with explicit override" do
    sign_in @admin
    data = draw_params
    data[:labor_draw_request][:submission_key] = SecureRandom.uuid
    data[:labor_draw_request][:labor_draw_items_attributes]["0"][:requested_amount] = 1200
    assert_no_difference [ "LaborDrawRequest.count", "LaborDrawItem.count" ] do
      post labor_draw_requests_path, params: data, as: :turbo_stream
      assert_response :unprocessable_entity
      assert_select "form[action='#{labor_draw_requests_path}'][method='post']"
      assert_select "input[data-amount][value='1200.0']"
    end
    assert_equal 0, @item.reload.labor_paid_amount
    assert_difference "LaborDrawRequest.count", 1 do
      post labor_draw_requests_path, params: data.merge(budget_override: "1", override_reason: "Approved extra work")
      assert_response :redirect
    end
    draw = LaborDrawRequest.last
    assert draw.approved?
    assert draw.budget_override?
    assert_equal "Approved extra work", draw.override_reason
    assert_equal(-200, @item.reload.labor_remaining_amount)
  end

  test "Engineer cannot use immediate approval inputs and another user cannot reuse a submission key" do
    data = draw_params
    data[:labor_draw_request].merge!(submission_key: SecureRandom.uuid, status: "approved", approved_by_id: @admin.id)
    post labor_draw_requests_path, params: data.merge(budget_override: "1", override_reason: "Forged approval")
    assert_response :redirect
    draw = LaborDrawRequest.last
    assert draw.pending?
    assert_nil draw.approved_by_id
    assert_equal @engineer.id, draw.user_id
    assert_equal 0, @item.reload.labor_paid_amount
    sign_in @admin
    assert_no_difference "LaborDrawRequest.count" do
      post labor_draw_requests_path, params: data
      assert_response :forbidden
    end
    assert_equal 0, @item.reload.labor_paid_amount
  end

  test "DV over-budget approval requires override and records Admin note atomically" do
    post labor_draw_requests_path, params: { labor_draw_request: draw_params[:labor_draw_request].merge(
      labor_draw_items_attributes: { "0" => { boq_item_id: @item.id, requested_amount: 1200 } }) }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[target='budget_warnings']", text: /exceeds the Master BOQ/
    draw = LaborDrawRequest.order(:id).last
    sign_in @admin
    patch approve_labor_draw_request_path(draw), params: { admin_note: "Inspected" }
    assert_response :unprocessable_entity
    assert draw.reload.pending?
    assert_nil draw.admin_note
    assert_equal 0, @item.reload.labor_paid_amount
    patch approve_labor_draw_request_path(draw), params: { budget_override: "1", override_reason: "Variation approved", admin_note: "Inspected" }
    assert_response :redirect
    assert draw.reload.approved?
    assert_equal "Inspected", draw.admin_note
    assert_equal(-200, @item.reload.labor_remaining_amount)
    assert_equal @admin.id, draw.approved_by_id
  end

  test "dashboard charts use actual work progress" do
    @item.update!(progress_percentage: 65)
    get dashboard_path, params: @context
    assert_response :success
    assert_select "#progress-chart-title", text: /65.0%/
    assert_select "[role='progressbar'][aria-valuenow='65.0']"
  end

  private

  def po_params(quantity: 2)
    { purchase_order: @context.merge(vendor_name: "Supplier", order_date: Date.current, status: "approved",
      po_items_attributes: { "0" => { boq_item_id: @item.id, item_name: "Forged name", quantity: quantity,
        material_unit_price: 200, labor_unit_price: 100, actual_material_unit_price: 999 } }) }
  end

  def draw_params
    { labor_draw_request: @context.merge(contractor_name: "Team A", request_date: Date.current, user_id: @admin.id,
      labor_draw_items_attributes: { "0" => { boq_item_id: @item.id, requested_amount: 400, unit_price: 1, paid_amount: 900 } }) }
  end
end
