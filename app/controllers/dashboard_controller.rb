class DashboardController < FinanceController
  def show
    @page_title = "ภาพรวมโครงการ"
    @master = @nav_plan&.master_boq
    @progress = BoqProgressSummary.new(@master)
    @material_budget = @master&.total_material_budget || 0
    @labor_budget = @master&.total_labor_budget || 0
    @budget = @material_budget + @labor_budget
    @material_spent = selected_orders.approved.sum(:total_material_amount)
    @labor_spent = selected_orders.approved.sum(:total_labor_amount) + selected_draws.approved.sum(:total_requested_amount)
    @spent = @material_spent + @labor_spent
    @pending_total = selected_orders.pending_pu.sum(:grand_total) + selected_draws.pending.sum(:total_requested_amount)
    @pending_count = selected_orders.pending_pu.count + selected_draws.pending.count
    @recent = (selected_orders.order(created_at: :desc).limit(5).to_a + selected_draws.order(created_at: :desc).limit(5).to_a).sort_by(&:created_at).reverse.first(6)
  end

  private

  helper_method :budget_share
  def budget_share(amount, total)
    return 0 unless total.to_d.positive?
    [ (amount.to_d / total.to_d * 100).round(1), 999 ].min
  end
end
