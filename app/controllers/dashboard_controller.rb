class DashboardController < FinanceController
  # Default: the whole project (every house plan). Passing house_plan_id narrows to one plan.
  def show
    @page_title = "ภาพรวมโครงการ"
    @plans = @nav_plans.to_a
    @plan_view = params[:house_plan_id].present? && @nav_plan.present?
    scope_plans = @plan_view ? [ @nav_plan ] : @plans
    plan_ids = scope_plans.map(&:id)

    @masters = MasterBoq.where(house_plan_id: plan_ids).to_a
    @progress = BoqProgressSummary.new(@masters)
    @material_budget = @masters.sum(&:total_material_budget)
    @labor_budget = @masters.sum(&:total_labor_budget)
    @budget = @material_budget + @labor_budget

    orders = PurchaseOrder.where(house_plan_id: plan_ids)
    draws = LaborDrawRequest.where(house_plan_id: plan_ids)
    @material_spent = orders.approved.sum(:total_material_amount)
    @labor_spent = orders.approved.sum(:total_labor_amount) + draws.approved.sum(:total_requested_amount)
    @spent = @material_spent + @labor_spent
    @pending_total = orders.pending_pu.sum(:grand_total) + draws.pending.sum(:total_requested_amount)
    @pending_count = orders.pending_pu.count + draws.pending.count
    @recent = (orders.preload(:po_items).order(created_at: :desc).limit(6).to_a +
      draws.preload(:labor_draw_items, :user).order(created_at: :desc).limit(6).to_a).sort_by(&:created_at).reverse.first(6)

    load_plan_breakdown(orders, draws) unless @plan_view
  end

  private

  helper_method :budget_share
  def budget_share(amount, total)
    return 0 unless total.to_d.positive?
    [ (amount.to_d / total.to_d * 100).round(1), 999 ].min
  end

  def load_plan_breakdown(orders, draws)
    masters = @masters.index_by(&:house_plan_id)
    material = orders.approved.group(:house_plan_id).sum(:total_material_amount)
    labor = orders.approved.group(:house_plan_id).sum(:total_labor_amount)
    paid = draws.approved.group(:house_plan_id).sum(:total_requested_amount)
    pending = orders.pending_pu.group(:house_plan_id).sum(:grand_total)
    draws.pending.group(:house_plan_id).sum(:total_requested_amount).each { |id, amount| pending[id] = pending.fetch(id, 0) + amount }

    @plan_rows = @plans.map do |plan|
      master = masters[plan.id]
      budget = master ? master.total_material_budget + master.total_labor_budget : 0
      { plan: plan, master: master, budget: budget,
        spent: material.fetch(plan.id, 0) + labor.fetch(plan.id, 0) + paid.fetch(plan.id, 0),
        pending: pending.fetch(plan.id, 0), progress: master ? BoqProgressSummary.new(master).overall : 0 }
    end
  end
end
