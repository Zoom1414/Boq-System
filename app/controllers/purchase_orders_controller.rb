class PurchaseOrdersController < FinanceController
  before_action :load_order, only: [ :show, :procure, :complete, :reject ]

  def index
    @page_title = "ประวัติใบสั่งซื้อ / สั่งจ้าง"
    @orders = selected_orders.order(order_date: :desc, id: :desc)
  end

  def pending
    @page_title = "รอจัดซื้อ / จัดจ้าง"
    @orders = selected_orders.pending_pu.order(:order_date, :id)
  end

  def history
    @page_title = "ประวัติการจัดซื้อ"
    @orders = selected_orders.approved.order(procurement_date: :desc, id: :desc)
  end

  def new
    authorize PurchaseOrder, :create?
    @page_title = "เปิดใบสั่งซื้อ / สั่งจ้าง"
    @order = PurchaseOrder.new(order_date: Date.current)
    @items = selected_items
  end

  def create
    authorize PurchaseOrder, :create?
    data = params.require(:purchase_order)
    plan = submitted_plan(data)
    @order = PurchaseOrder.new(data.permit(:vendor_name, :order_date))
    @order.assign_attributes(project: plan.project, house_plan: plan, status: :pending_pu, po_number: DocumentSequence.next_number("PO"))
    rows = data.fetch(:po_items_attributes, ActionController::Parameters.new).values
    raise ActionController::BadRequest, "Too many items" if rows.size > 500
    rows.each do |row|
      attributes = row.permit(:boq_item_id, :item_name, :unit, :quantity, :material_unit_price, :labor_unit_price)
      if attributes[:boq_item_id].present?
        item = plan.master_boq&.boq_items&.find(attributes[:boq_item_id])
        raise ActiveRecord::RecordNotFound unless item
        attributes.merge!(item_name: item.name, unit: item.unit)
      else
        attributes[:boq_item_id] = nil
      end
      @order.po_items.build(attributes)
    end
    if @order.save
      document_saved(@order)
    else
      @items = plan.master_boq&.boq_items || BoqItem.none
      @page_title = "เปิดใบสั่งซื้อ / สั่งจ้าง"
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize @order, :show?
    @page_title = @order.po_number
  end

  def procure
    authorize @order, :approve?
    @page_title = "บันทึกราคาซื้อ / จ้างจริง"
    @order.procurement_date ||= Date.current
  end

  def complete
    authorize @order, :approve?
    data = params.require(:purchase_order).permit(:procurement_date, po_items_attributes: [ :id, :actual_material_unit_price ])
    @order = CompleteProcurementService.new(@order, actor: current_user, attributes: data,
      override: params[:budget_override] == "1", override_reason: params[:override_reason]).call
    redirect_to purchase_order_path(@order), notice: "อนุมัติจัดซื้อและปรับยอด BOQ แล้ว", status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ApproveDocumentService::InvalidState,
      ApproveDocumentService::BudgetExceeded, ApproveDocumentService::OverrideReasonRequired => error
    @order.reload
    @error = error.message
    render :procure, status: :unprocessable_entity
  end

  def reject
    authorize @order, :approve?
    RejectDocumentService.call(@order, actor: current_user, note: params[:admin_note])
    redirect_to @order, notice: "ปฏิเสธคำขอแล้ว", status: :see_other
  rescue ActiveRecord::RecordInvalid, ApproveDocumentService::InvalidState => error
    redirect_to @order, alert: error.message, status: :see_other
  end

  private

  def load_order
    @order = PurchaseOrder.includes(po_items: :boq_item).find(params[:id])
    use_document_navigation(@order)
  end
end
