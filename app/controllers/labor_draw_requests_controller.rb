class LaborDrawRequestsController < FinanceController
  before_action :load_draw, only: [ :show, :approve, :reject ]

  def index
    @page_title = "ประวัติการเบิกจ่ายค่าแรง"
    @draws = selected_draws.order(request_date: :desc, id: :desc)
    @paid_draws = @draws.select(&:approved?)
    @monthly = @paid_draws.group_by { |draw| draw.request_date.beginning_of_month }
  end

  def new
    @draw = LaborDrawRequest.new(user: current_user, request_date: Date.current, submission_key: SecureRandom.uuid)
    authorize @draw, :show?
    load_contractors
    @draw.contractor = @contractors.find { |c| c.id.to_s == params[:contractor_id].to_s } ||
      @contractors.find { |c| c.full_name == params[:contractor_name].to_s.squish } || @contractors.first
    @items = selected_items.where(contractor_id: @draw.contractor_id)
    @page_title = "เบิกจ่ายค่าแรง"
  end

  def create
    @draw = LaborDrawRequest.new(user: current_user)
    authorize @draw, :create?
    data = params.require(:labor_draw_request)
    plan = submitted_plan(data)
    @draw.assign_attributes(data.permit(:request_date, :submission_key))
    # The contractor must come from the registry; the name is only accepted for older form posts.
    @draw.contractor = data[:contractor_id].present? ? Contractor.find_by(id: data[:contractor_id]) : Contractor.find_by_name(data[:contractor_name])
    @draw.contractor_name = @draw.contractor&.full_name
    @draw.assign_attributes(project: plan.project, house_plan: plan, status: :pending, dv_number: DocumentSequence.next_number("DV"))
    use_document_navigation(@draw)
    rows = data.fetch(:labor_draw_items_attributes, ActionController::Parameters.new).values
    raise ActionController::BadRequest, "Too many items" if rows.size > 500
    rows.each do |row|
      amount = row[:requested_amount]
      next if amount.blank? || amount.to_s.match?(/\A0+(\.0+)?\z/)
      raise ActiveRecord::RecordNotFound unless @draw.contractor
      item = plan.master_boq&.boq_items&.where(contractor_id: @draw.contractor_id)&.find(row[:boq_item_id])
      raise ActiveRecord::RecordNotFound unless item
      @draw.labor_draw_items.build(boq_item: item, work_description: item.name,
        quantity: item.material_quantity, unit_price: item.labor_unit_price, requested_amount: amount)
    end
    @draw = SubmitLaborDrawService.new(@draw, actor: current_user, override: params[:budget_override] == "1",
      override_reason: params[:override_reason]).call
    document_saved(@draw)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ApproveDocumentService::InvalidState,
      ApproveDocumentService::BudgetExceeded, ApproveDocumentService::OverrideReasonRequired => error
    @error = error.is_a?(ApproveDocumentService::BudgetExceeded) ? "ยอดเบิกเกินงบคงเหลือ กรุณาปรับยอด หรือระบุเหตุผลอนุมัติเกินงบด้านล่าง" : error.message
    @page_title = "เบิกจ่ายค่าแรง"
    load_contractors
    @items = selected_items.where(contractor_id: @draw.contractor_id)
    render :new, status: :unprocessable_entity
  end

  def show
    authorize @draw, :show?
    @page_title = @draw.dv_number
  end

  def approve
    authorize @draw, :approve?
    @draw = ApproveLaborDrawService.new(@draw, actor: current_user,
      override: params[:budget_override] == "1", override_reason: params[:override_reason],
      admin_note: params.permit(:admin_note)[:admin_note]).call
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
    @draw = LaborDrawRequest.includes(:user, :contractor, labor_draw_items: :boq_item).find(params[:id])
    use_document_navigation(@draw)
  end

  def load_contractors
    @contractors = Contractor.where(id: selected_items.reorder(nil).where.not(contractor_id: nil).select(:contractor_id)).order(:full_name).to_a
  end
end
