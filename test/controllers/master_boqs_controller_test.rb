require "test_helper"

class MasterBoqsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    setup_boq
    sign_in @engineer
  end

  test "worksheet shows grouped budgets and scoped project selectors" do
    get master_boq_path(project_id: @project.id, house_plan_id: @plan.id)
    assert_response :success
    assert_select ".boq-table thead tr", count: 2
    assert_select ".boq-item-row", count: 1
    assert_select "#boq_project_id"
    assert_select "#boq_house_plan_id"
    assert_select "turbo-frame#boq_editor"
    get master_boq_path(project_id: projects(:two).id, house_plan_id: @plan.id)
    assert_response :not_found
  end

  test "viewing a plan does not create a master and explicit creation is idempotent" do
    other = house_plans(:two)
    assert_no_difference "MasterBoq.count" do
      get master_boq_path(project_id: other.project_id, house_plan_id: other.id)
      assert_response :success
    end
    assert_difference "MasterBoq.count", 1 do
      2.times { post create_master_boq_path(other) }
    end
  end

  test "new and edit forms load inside the editor frame" do
    [ new_master_boq_boq_category_path(@master), edit_master_boq_boq_category_path(@master, @category),
      new_master_boq_boq_item_path(@master), edit_master_boq_boq_item_path(@master, @item) ].each do |path|
      get path, headers: { "Turbo-Frame" => "boq_editor" }
      assert_response :success
      assert_select "turbo-frame#boq_editor dialog"
    end
  end

  test "Turbo creation replaces the worksheet, totals, and first-item button" do
    post master_boq_boq_categories_path(@master), params: { boq_category: { name: "Foundation", position: 2 } }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[target='boq-add-item']"
    assert_difference "BoqItem.count", 1 do
      post master_boq_boq_items_path(@master), params: { boq_item: {
        boq_category_id: @category.id, code: "NEW", name: "New material", unit: "m3",
        material_quantity: 2, material_unit_price: 10, labor_unit_price: 5,
        material_used_qty: 99, labor_paid_amount: 99
      } }, as: :turbo_stream
    end
    assert_response :success
    assert_select "turbo-stream[target='boq-worksheet']"
    assert_select "turbo-stream[target='boq-summary']"
    item = @category.boq_items.find_by!(code: "NEW")
    assert_equal 20, item.material_total
    assert_equal 0, item.material_used_qty
    assert_equal 0, item.labor_paid_amount
  end

  test "invalid edits return the form and stale edits preserve current data" do
    patch master_boq_boq_item_path(@master, @item), params: { boq_item: { name: "", lock_version: @item.lock_version } }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-frame#boq_editor [role='alert']"
    version = @item.lock_version
    @item.update!(name: "Latest")
    patch master_boq_boq_item_path(@master, @item), params: { boq_item: { name: "Stale", lock_version: version } }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_equal "Latest", @item.reload.name
  end

  test "ordinary users can read and export but cannot modify BOQ" do
    @engineer.update!(role: :user)
    get master_boq_path
    assert_response :success
    get export_master_boq_path(@master)
    assert_response :success
    post master_boq_boq_categories_path(@master), params: { boq_category: { name: "Forbidden" } }
    assert_response :forbidden
    patch master_boq_boq_item_path(@master, @item), params: { boq_item: { name: "Forbidden" } }
    assert_response :forbidden
  end

  test "items from other masters cannot be edited or assigned" do
    other_master = MasterBoq.create!(house_plan: house_plans(:two))
    other_category = other_master.boq_categories.create!(name: "Other")
    patch master_boq_boq_item_path(other_master, @item), params: { boq_item: { name: "Wrong" } }
    assert_response :not_found
    sign_in @engineer
    post master_boq_boq_items_path(@master), params: { boq_item: { boq_category_id: other_category.id, code: "Wrong" } }
    assert_response :not_found
  end

  test "CSV export escapes spreadsheet formulas and backup includes BOQ rows" do
    @item.update!(name: "=HYPERLINK(1)")
    get export_master_boq_path(@master)
    assert_response :success
    assert_includes response.body, "'=HYPERLINK(1)"
    assert_includes response.headers["Content-Disposition"], ".csv"
    get backup_master_boq_path(@master)
    assert_response :success
    assert_equal @item.id, JSON.parse(response.body).dig("master_boq", "boq_categories", 0, "boq_items", 0, "id")
  end
end
