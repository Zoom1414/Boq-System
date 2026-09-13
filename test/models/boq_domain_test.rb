require "test_helper"

class BoqDomainTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "decimal totals, balances and master rollups follow item changes" do
    @item.update!(material_quantity: "3.1250", material_unit_price: "10.23", labor_unit_price: "4.57")
    assert_equal BigDecimal("31.97"), @item.material_total
    assert_equal BigDecimal("14.28"), @item.labor_total
    assert_equal BigDecimal("3.125"), @item.material_remaining_qty
    assert_equal @item.labor_total, @item.labor_remaining_amount
    assert_equal @item.material_total, @master.reload.total_material_budget
    assert_equal @item.labor_total, @master.total_labor_budget
    @item.destroy!
    assert_equal 0, @master.reload.total_labor_budget
  end

  test "negative inputs and invalid progress are rejected" do
    @item.assign_attributes(material_quantity: -1, labor_unit_price: -1, progress_percentage: 101)
    assert_not @item.valid?
    assert @item.errors[:material_quantity].any?
    assert @item.errors[:labor_unit_price].any?
    assert @item.errors[:progress_percentage].any?
  end

  test "balances cannot be assigned by normal model updates" do
    assert_not @item.update(labor_paid_amount: 100)
    assert_equal 0, @item.reload.labor_paid_amount
  end

  test "pending totals combine PO and DV without deducting balances" do
    draw = build_draw
    draw.save!
    po = create_po
    assert_equal 400, draw.reload.total_requested_amount
    assert_equal 500, po.reload.total_material_amount
    assert_equal 200, po.total_labor_amount
    assert_equal 700, po.grand_total
    assert_equal 600, @item.pending_labor_amount
    assert_equal 2, @item.pending_material_quantity
    assert_equal 0, @item.reload.labor_paid_amount
    assert_equal 0, @item.material_used_qty
    draw.update!(status: :rejected)
    assert_equal 200, @item.pending_labor_amount
  end

  test "line edits and deletion recalculate document totals" do
    draw = build_draw
    draw.save!
    draw.labor_draw_items.first.update!(requested_amount: 125)
    assert_equal 125, draw.reload.total_requested_amount
    po = create_po
    po.po_items.first.update!(quantity: 3, actual_material_unit_price: 0)
    assert_equal 300, po.reload.grand_total
    po.po_items.first.destroy!
    assert_equal 0, po.reload.grand_total
  end

  test "multiple nested PO items are all persisted and totaled" do
    second = create_boq_item("STEEL")
    po = create_po
    po.update!(po_items_attributes: [ { boq_item_id: second.id, item_name: "Steel", quantity: 1,
      material_unit_price: 10, labor_unit_price: 20 } ])
    assert_equal 2, po.reload.po_items.count
    assert_equal 730, po.grand_total
  end

  test "over budget requests persist with warning details" do
    draw = build_draw(amount: 1001)
    draw.save!
    assert_equal BudgetCheckService::WARNING, draw.budget_warnings.first[:message]
    assert_equal 1, draw.budget_warnings.first[:labor_shortfall]
    po = create_po(quantity: 11)
    assert_equal 1, po.budget_warnings.first[:material_shortfall]
    assert_equal 0, @item.reload.material_used_qty
  end

  test "plan, project, contractor and requester must match" do
    draw = build_draw
    draw.project = projects(:two)
    assert_not draw.valid?
    draw.project = @project
    draw.house_plan = house_plans(:two)
    assert_not draw.valid?
    draw.house_plan = @plan
    draw.contractor_name = "Team B"
    assert_not draw.valid?
    draw.contractor_name = "Team A"
    draw.user = @admin
    assert_not draw.valid?
  end

  test "identifiers, one master per plan and nonempty requests are enforced" do
    assert_not MasterBoq.new(house_plan: @plan).valid?
    assert_not Project.new(name: "Duplicate", code: @project.code).valid?
    draw = build_draw
    draw.labor_draw_items.clear
    assert_not draw.valid?
    assert_includes draw.errors[:base], "At least one item is required"
  end

  test "referenced BOQ items cannot be deleted" do
    build_draw.save!
    assert_not @item.destroy
    assert BoqItem.exists?(@item.id)
  end

  test "existing hierarchy nodes cannot move and invalidate financial references" do
    assert_not @plan.update(project: projects(:two))
    assert_not @master.update(house_plan: house_plans(:two))
    other_master = MasterBoq.create!(house_plan: house_plans(:two))
    assert_not @category.update(master_boq: other_master)
  end
end
