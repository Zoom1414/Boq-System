require "test_helper"

class BoqProgressSummaryTest < ActiveSupport::TestCase
  setup { setup_boq }

  def use_material(item, quantity)
    item.balance_update_in_progress = true
    item.update!(material_used_qty: quantity)
  end

  test "progress is materials used against BOQ quantity, weighted by budget" do
    use_material(@item, 10)
    second = create_boq_item("SECOND")
    second.update!(material_quantity: 30)
    summary = BoqProgressSummary.new(@master)
    assert_equal 100, @item.completion_percentage
    assert_equal 25, summary.overall
    assert_equal 25, summary.categories.first[:progress]
    assert_equal 1, summary.completed_count
    draw = build_draw.tap(&:save!)
    ApproveLaborDrawService.new(draw, actor: @admin).call
    assert_equal 25, BoqProgressSummary.new(@master).overall
  end

  test "overuse shows above 100 on the item but is capped in totals" do
    use_material(@item, 12)
    assert_equal 120, @item.completion_percentage
    assert_equal 100, BoqProgressSummary.new(@master).overall
  end

  test "labor-only rows use labor paid and missing masters have no progress" do
    @item.update!(material_quantity: 0)
    assert_equal 0, @item.completion_percentage
    assert_equal 0, BoqProgressSummary.new(nil).overall
    assert_empty BoqProgressSummary.new(nil).categories
  end

  test "a project summary combines plans and merges same-named categories" do
    other = MasterBoq.create!(house_plan: house_plans(:two))
    category = other.boq_categories.create!(name: "Structure", position: 1)
    row = category.boq_items.create!(code: "X", name: "X", unit: "m3", material_quantity: 10, material_unit_price: 200, labor_unit_price: 100)
    use_material(row, 5)
    summary = BoqProgressSummary.new([ @master, other ])
    assert_equal 2, summary.items.size
    assert_equal 1, summary.categories.size
    assert_equal 25, summary.overall
  end
end
