require "test_helper"

class BoqProgressSummaryTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "work progress is budget weighted and independent of approved payments" do
    @item.update!(progress_percentage: 100)
    second = create_boq_item("SECOND")
    second.update!(material_quantity: 30, progress_percentage: 0)
    summary = BoqProgressSummary.new(@master)
    assert_equal 25, summary.overall
    assert_equal 25, summary.categories.first[:progress]
    assert_equal 1, summary.completed_count
    draw = build_draw.tap(&:save!)
    ApproveLaborDrawService.new(draw, actor: @admin).call
    assert_equal 25, BoqProgressSummary.new(@master).overall
  end

  test "zero-budget work uses a simple average and missing masters have no progress" do
    @item.update!(material_unit_price: 0, labor_unit_price: 0, progress_percentage: 60)
    assert_equal 60, BoqProgressSummary.new(@master).overall
    assert_equal 0, BoqProgressSummary.new(nil).overall
    assert_empty BoqProgressSummary.new(nil).categories
  end
end
