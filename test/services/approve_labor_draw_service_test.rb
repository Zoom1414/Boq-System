require "test_helper"

class ApproveLaborDrawServiceTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "approval deducts once and records approval-time snapshots" do
    draw = build_draw
    draw.save!
    approved = ApproveLaborDrawService.new(draw, actor: @admin).call
    assert approved.approved?
    assert_equal @admin, approved.approved_by
    assert approved.approved_at
    assert_equal 400, @item.reload.labor_paid_amount
    assert_equal 600, @item.labor_remaining_amount
    assert_equal 0, @item.pending_labor_amount
    assert_equal 0, approved.labor_draw_items.first.paid_amount
    assert_equal 600, approved.labor_draw_items.first.remaining_amount
    ApproveLaborDrawService.new(draw, actor: @admin).call
    assert_equal 400, @item.reload.labor_paid_amount
  end

  test "a second pending draw is checked against the latest approved balance" do
    first = build_draw(amount: 700)
    second = build_draw(amount: 500)
    first.save!
    second.save!
    ApproveLaborDrawService.new(first, actor: @admin).call
    assert_raises(ApproveLaborDrawService::BudgetExceeded) do
      ApproveLaborDrawService.new(second, actor: @admin).call
    end
    assert second.reload.pending?
    assert_equal 700, @item.reload.labor_paid_amount
    assert_nil second.approved_at
  end

  test "exact budget is allowed and a later approval snapshots prior payments" do
    first = build_draw(amount: 400)
    second = build_draw(amount: 600)
    first.save!
    second.save!
    ApproveLaborDrawService.new(first, actor: @admin).call
    approved = ApproveLaborDrawService.new(second, actor: @admin).call
    assert_equal 400, approved.labor_draw_items.first.paid_amount
    assert_equal 0, approved.labor_draw_items.first.remaining_amount
    assert_equal 0, @item.reload.labor_remaining_amount
  end

  test "only Admin can approve including when override is requested" do
    draw = build_draw
    draw.save!
    [ @engineer, nil ].each do |actor|
      assert_raises(Pundit::NotAuthorizedError) do
        ApproveLaborDrawService.new(draw, actor: actor, override: true, override_reason: "test").call
      end
    end
    @engineer.update!(role: :dev)
    assert_raises(Pundit::NotAuthorizedError) { ApproveLaborDrawService.new(draw, actor: @engineer).call }
    assert_equal 0, @item.reload.labor_paid_amount
  end

  test "explicit Admin override permits negative remaining and retains its reason" do
    draw = build_draw(amount: 1200)
    draw.save!
    assert_raises(ApproveLaborDrawService::OverrideReasonRequired) do
      ApproveLaborDrawService.new(draw, actor: @admin, override: true).call
    end
    approved = ApproveLaborDrawService.new(draw, actor: @admin, override: true, override_reason: "Approved scope variation").call
    assert approved.budget_override?
    assert_equal "Approved scope variation", approved.override_reason
    assert_equal(-200, @item.reload.labor_remaining_amount)
  end

  test "a failure after the first line rolls back all balances and status" do
    second = create_boq_item("STEEL")
    draw = build_draw
    draw.labor_draw_items.build(boq_item: second, work_description: "Steel", quantity: 1, unit_price: 100, requested_amount: 100)
    draw.save!
    failing_service = Class.new(ApproveLaborDrawService) do
      def apply_line!(row, item)
        super
        raise "Simulated write failure" if item.code == "STEEL"
      end
    end
    assert_raises(RuntimeError) { failing_service.new(draw, actor: @admin).call }
    assert_equal 0, @item.reload.labor_paid_amount
    assert_equal 0, second.reload.labor_paid_amount
    assert draw.reload.pending?
    assert_nil draw.approved_by_id
  end

  test "approved documents and lines cannot be changed or deleted" do
    draw = build_draw
    draw.save!
    approved = ApproveLaborDrawService.new(draw, actor: @admin).call
    assert_not approved.update(status: :rejected)
    approved.reload
    assert_not approved.destroy
    line = approved.labor_draw_items.first
    assert_not line.update(requested_amount: 999)
    assert_not line.destroy
    assert_equal 400, @item.reload.labor_paid_amount
  end

  test "direct approval, audit forgery and rejected approval are blocked" do
    draw = build_draw
    draw.save!
    assert_not draw.update(status: :approved)
    draw.reload
    assert_not draw.update(approved_by: @admin, approved_at: Time.current)
    draw.reload.update!(status: :rejected)
    assert_raises(ApproveLaborDrawService::InvalidState) { ApproveLaborDrawService.new(draw, actor: @admin).call }
    assert_equal 0, @item.reload.labor_paid_amount
  end
end
