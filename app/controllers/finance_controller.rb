class FinanceController < ApplicationController
  private

  def selected_items
    @nav_plan&.master_boq ? @nav_plan.master_boq.boq_items.includes(:boq_category).order(:code) : BoqItem.none
  end

  def selected_orders
    PurchaseOrder.where(house_plan_id: @nav_plan&.id).preload(:po_items)
  end

  def selected_draws
    LaborDrawRequest.where(house_plan_id: @nav_plan&.id).preload(:labor_draw_items, :user)
  end

  def submitted_plan(parameters)
    project = Project.find(parameters.require(:project_id))
    project.house_plans.find(parameters.require(:house_plan_id))
  end

  def use_document_navigation(document)
    @nav_project = document.project
    @nav_plan = document.house_plan
    @nav_plans = @nav_project.house_plans.order(:name)
    session[:project_id] = @nav_project.id
    session[:house_plan_id] = @nav_plan.id
  end

  def document_saved(document)
    @document = document
    respond_to do |format|
      format.html { redirect_to document, notice: "บันทึกคำขอแล้ว รอ Admin อนุมัติ", status: :see_other }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("finance-form", partial: "finance/saved", locals: { document: document }),
          helpers.budget_warning_stream(document)
        ]
      end
    end
  end
end
