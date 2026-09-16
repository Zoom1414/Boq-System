class DashboardController < FinanceController
  def show
    @page_title = "ภาพรวมโครงการ"
    @master = @nav_plan&.master_boq
    @progress = BoqProgressSummary.new(@master)
    @material_spent = selected_orders.approved.sum(:total_material_amount)
    @labor_spent = selected_orders.approved.sum(:total_labor_amount) + selected_draws.approved.sum(:total_requested_amount)
    @pending_total = selected_orders.pending_pu.sum(:grand_total) + selected_draws.pending.sum(:total_requested_amount)
    @recent = (selected_orders.order(created_at: :desc).limit(5).to_a + selected_draws.order(created_at: :desc).limit(5).to_a).sort_by(&:created_at).reverse.first(6)
  end
end
