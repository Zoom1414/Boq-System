require "test_helper"

class BudgetWarningsHelperTest < ActionView::TestCase
  include BudgetWarningsHelper
  include Turbo::StreamsHelper

  setup { setup_boq }

  test "budget warning is rendered in a Turbo Stream alert" do
    draw = build_draw(amount: 1001)
    view.extend(BudgetWarningsHelper)
    render html: view.budget_warning_stream(draw)
    assert_select "turbo-stream[action='update'][target='budget_warnings']" do
      assert_select "[role='alert']", text: /Warning: This request exceeds the Master BOQ budget limit/
    end
  end
end
