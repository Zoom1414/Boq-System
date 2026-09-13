require "csv"

class MasterBoqsController < ApplicationController
  layout "boq"

  def show
    authorize MasterBoq, :show?
    @projects = Project.order(:name)
    @project = params[:project_id].present? ? @projects.find(params[:project_id]) : @nav_project
    @house_plans = @project ? @project.house_plans.order(:name) : HousePlan.none
    @house_plan = params[:house_plan_id].present? ? @house_plans.find(params[:house_plan_id]) : @nav_plan
    @master = @house_plan&.master_boq
    @categories = @master ? @master.boq_categories.includes(:boq_items) : BoqCategory.none
    @pending_quantities = @master ? PoItem.joins(:purchase_order)
      .where(boq_item_id: @master.boq_items.select(:id), purchase_orders: { status: "pending_pu" })
      .group(:boq_item_id).sum(:quantity) : {}
  end

  def create
    authorize MasterBoq, :create?
    plan = HousePlan.find(params[:house_plan_id])
    plan.with_lock { plan.create_master_boq! unless plan.master_boq }
    redirect_to master_boq_path(project_id: plan.project_id, house_plan_id: plan.id), notice: "สร้าง Master BOQ แล้ว เพิ่มหมวดงานเพื่อเริ่มบันทึกรายการ"
  end

  def export
    master = MasterBoq.find(params[:id])
    authorize master, :export?
    body = CSV.generate do |csv|
      csv << ImportBoqService::HEADERS
      master.boq_categories.includes(:boq_items).each do |category|
        category.boq_items.each do |item|
          csv << [ csv_safe(category.name), *ImportBoqService::ITEM_FIELDS.map { |field| csv_safe(item.public_send(field)) } ]
        end
      end
    end
    send_data "\uFEFF#{body}", filename: "boq-#{master.id}.csv", type: "text/csv; charset=utf-8", disposition: "attachment"
  end

  def backup
    master = MasterBoq.find(params[:id])
    authorize master, :backup?
    data = { exported_at: Time.current.iso8601, house_plan: master.house_plan.attributes,
      master_boq: master.as_json(include: { boq_categories: { include: :boq_items } }) }
    send_data JSON.pretty_generate(data), filename: "boq-#{master.id}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.json", type: "application/json", disposition: "attachment"
  end

  def import
    master = MasterBoq.find(params[:id])
    authorize master, :import?
    ImportBoqService.new(master, params[:file]).call
    redirect_to master_boq_path(project_id: master.house_plan.project_id, house_plan_id: master.house_plan_id), notice: "นำเข้ารายการ BOQ เรียบร้อยแล้ว"
  rescue ImportBoqService::InvalidFile, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    redirect_to master_boq_path(project_id: master.house_plan.project_id, house_plan_id: master.house_plan_id), alert: "นำเข้าไม่สำเร็จ: #{error.message}"
  end

  private

  def csv_safe(value)
    value.is_a?(String) && value.match?(/\A[=+\-@\t\r]/) ? "'#{value}" : value
  end
end
