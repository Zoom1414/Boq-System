class BoqWorkspaceController < ApplicationController
  before_action :load_master

  private

  def load_master
    @master = MasterBoq.find(params[:master_boq_id])
    authorize @master, :update?
  end

  def load_worksheet
    @master.reload
    @house_plan = @master.house_plan
    @categories = @master.boq_categories.includes(:boq_items)
    @pending_quantities = PoItem.joins(:purchase_order)
      .where(boq_item_id: @master.boq_items.select(:id), purchase_orders: { status: "pending_pu" })
      .group(:boq_item_id).sum(:quantity)
  end

  def saved_response(message)
    load_worksheet
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("boq-worksheet", partial: "master_boqs/worksheet"),
          turbo_stream.replace("boq-summary", partial: "master_boqs/summary"),
          turbo_stream.replace("boq-category-select", partial: "master_boqs/category_select"),
          turbo_stream.replace("boq-add-item", partial: "master_boqs/add_item_button"),
          turbo_stream.update("boq_editor", ""),
          turbo_stream.update("boq-notice", helpers.tag.div(message, class: "boq-success", role: "status"))
        ]
      end
      format.html { redirect_to master_boq_path(project_id: @house_plan.project_id, house_plan_id: @house_plan.id), notice: message }
    end
  end
end
