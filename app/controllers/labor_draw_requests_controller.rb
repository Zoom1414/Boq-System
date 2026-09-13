class LaborDrawRequestsController < FinanceController
  before_action :load_draw, only: [ :show, :approve, :reject ]

  def index
    @page_title = "ประวัติการเบิกจ่ายค่าแรง"
    @draws = selected_draws.order(request_date: :desc, id: :desc)
    @paid_draws = @draws.select(&:approved?)
    @monthly = @paid_draws.group_by { |draw| draw.request_date.beginning_of_month }
  end

  def new
    @draw = LaborDrawRequest.new(user: current_user, request_date: Date.current)
    authorize @draw, :create?
    load_contractors
    @draw.contractor_name = @contractors.include?(params[:contractor_name]) ? params[:contractor_name] : @contractors.first
    @items = selected_items.where(contractor_name: @draw.contractor_name)
    @page_title = "เบิกจ่ายค่าแรง"
  end

  def create
    @draw = LaborDrawRequest.new(user: current_user)
    authorize @draw, :create?
    data = params.require(:labor_draw_request)
    plan = submitted_plan(data)
    @draw.assign_attributes(data.permit(:contractor_name, :request_date))
    @draw.assign_attributes(project: plan.project, house_plan: plan, status: :pending, dv_number: DocumentSequence.next_number("DV"))
    rows = data.fetch(:labor_draw_items_attributes, ActionController::Parameters.new).values
    raise ActionController::BadRequest, "Too many items" if rows.size > 500
    rows.each do |row|
      amount = row[:requested_amount]
      next if amount.blank? || amount.to_s.match?(/\A0+(\.0+)?\z/)
      item = plan.master_boq&.boq_items&.where(contractor_name: @draw.contractor_name)&.find(row[:boq_item_id])
      raise ActiveRecord::RecordNotFound unless item
      @draw.labor_draw_items.build(boq_item: item, work_description: item.name,
        quantity: item.material_quantity, unit_price: item.labor_unit_price, requested_amount: amount)
    end
    if @draw.save
      document_saved(@draw)
    else
      load_contractors
      @items = selected_items.where(contractor_name: @draw.contractor_name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize @draw, :show?
    @page_title = @draw.dv_number
  end

  def approve
    authorize @draw, :approve?
    @draw = ApproveLaborDrawService.new(@draw, actor: current_user,
      override: params[:budget_override] == "1", override_reason: params[:override_reason]).call
    redirect_to @draw, notice: "อนุมัติและหักยอดค่าแรงแล้ว", status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ApproveDocumentService::InvalidState,
      ApproveDocumentService::BudgetExceeded, ApproveDocumentService::OverrideReasonRequired => error
    @draw.reload
    @error = error.message
    render :show, status: :unprocessable_entity
  end

  def reject
    authorize @draw, :approve?
    RejectDocumentService.call(@draw, actor: current_user, note: params[:admin_note])
    redirect_to @draw, notice: "ปฏิเสธคำขอแล้ว", status: :see_other
  rescue ActiveRecord::RecordInvalid, ApproveDocumentService::InvalidState => error
    redirect_to @draw, alert: error.message, status: :see_other
  end

  private

  def load_draw
    @draw = LaborDrawRequest.includes(:user, labor_draw_items: :boq_item).find(params[:id])
    use_document_navigation(@draw)
  end

  def load_contractors
    @contractors = selected_items.where.not(contractor_name: [ nil, "" ]).reorder(nil).distinct.pluck(:contractor_name).sort
  end
end
