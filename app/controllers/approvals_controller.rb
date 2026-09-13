class ApprovalsController < FinanceController
  def index
    @page_title = "คำขอรออนุมัติ"
    @status = %w[pending approved rejected all].include?(params[:status]) ? params[:status] : "pending"
    orders, draws = selected_orders, selected_draws
    if @status != "all"
      orders = orders.where(status: @status == "pending" ? "pending_pu" : @status)
      draws = draws.where(status: @status)
    end
    @documents = (orders.to_a + draws.to_a).sort_by(&:created_at).reverse
  end
end
