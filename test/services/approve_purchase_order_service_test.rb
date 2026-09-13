require "test_helper"

class ApprovePurchaseOrderServiceTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "PU approval uses actual price and deducts quantity and labor exactly once" do
    po = create_po
    approved = ApprovePurchaseOrderService.new(po, actor: @admin).call
    assert approved.approved?
    assert_equal 700, approved.grand_total
    assert_equal 2, @item.reload.material_used_qty
    assert_equal 8, @item.material_remaining_qty
    assert_equal 200, @item.labor_paid_amount
    ApprovePurchaseOrderService.new(po, actor: @admin).call
    assert_equal 2, @item.reload.material_used_qty
  end

  test "missing PU actual price rejects approval without deductions" do
    po = create_po(actual_price: nil)
    assert_raises(ApprovePurchaseOrderService::InvalidState) { ApprovePurchaseOrderService.new(po, actor: @admin).call }
    assert_equal 0, @item.reload.material_used_qty
    assert po.reload.pending_pu?
  end

  test "PO quantity overrun requires an explicit Admin override" do
    po = create_po(quantity: 11)
    assert_raises(ApprovePurchaseOrderService::BudgetExceeded) { ApprovePurchaseOrderService.new(po, actor: @admin).call }
    assert_equal 0, @item.reload.material_used_qty
    ApprovePurchaseOrderService.new(po, actor: @admin, override: true, override_reason: "Extra work").call
    assert_equal(-1, @item.reload.material_remaining_qty)
  end
end
