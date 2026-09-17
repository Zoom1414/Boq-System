class ContractorsController < ApplicationController
  STATUS_FILTERS = %w[active inactive incomplete].freeze

  before_action :load_contractor, only: %i[show edit update]

  def index
    authorize Contractor
    @page_title = "ทะเบียนช่าง / ผู้รับเหมา"
    @query = params[:q].to_s.squish
    @trade = params[:trade].presence
    @status = params[:status].presence_in(STATUS_FILTERS)

    scope = Contractor.search(@query).order(:full_name)
    scope = scope.where(trade: @trade) if @trade
    scope = case @status
    when "active" then scope.active
    when "inactive" then scope.where(active: false)
    when "incomplete" then scope.bank_incomplete
    else scope
    end
    @contractors = scope.to_a

    ids = @contractors.map(&:id)
    draws = LaborDrawRequest.where(contractor_id: ids).group(:contractor_id)
    @paid = draws.approved.sum(:total_requested_amount)
    @pending = draws.pending.sum(:total_requested_amount)
    @job_counts = BoqItem.where(contractor_id: ids).group(:contractor_id).count
    @trades = Contractor.where.not(trade: nil).distinct.order(:trade).pluck(:trade)
    @stats = { total: Contractor.count, active: Contractor.active.count, incomplete: Contractor.bank_incomplete.count,
      paid: LaborDrawRequest.approved.where.not(contractor_id: nil).sum(:total_requested_amount) }
  end

  def show
    authorize @contractor
    @page_title = @contractor.full_name
    @draws = @contractor.labor_draw_requests.includes(:project, :house_plan, :labor_draw_items).order(request_date: :desc, id: :desc).to_a
    @approved = @draws.select(&:approved?)
    @paid_total = @approved.sum(&:total_requested_amount)
    @pending_total = @draws.select(&:pending?).sum(&:total_requested_amount)
    @jobs = @contractor.boq_items.includes(boq_category: { master_boq: { house_plan: :project } }).order(:code).to_a
  end

  def new
    @contractor = Contractor.new
    authorize @contractor
    @page_title = "เพิ่มช่าง / ผู้รับเหมา"
  end

  def create
    @contractor = Contractor.new(contractor_params)
    authorize @contractor
    if @contractor.save
      redirect_to contractor_path(@contractor), notice: "บันทึกข้อมูลช่างแล้ว", status: :see_other
    else
      @page_title = "เพิ่มช่าง / ผู้รับเหมา"
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @contractor.errors.add(:base, "ชื่อหรือเลขบัญชีซ้ำกับช่างที่เพิ่งบันทึก กรุณาตรวจสอบอีกครั้ง")
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @contractor
    @page_title = "แก้ไขข้อมูลช่าง"
  end

  def update
    authorize @contractor
    if @contractor.update(contractor_params)
      redirect_to contractor_path(@contractor), notice: "บันทึกการแก้ไขแล้ว", status: :see_other
    else
      @page_title = "แก้ไขข้อมูลช่าง"
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @contractor.errors.add(:base, "ชื่อหรือเลขบัญชีซ้ำกับช่างคนอื่น กรุณาตรวจสอบอีกครั้ง")
    render :edit, status: :unprocessable_entity
  end

  private

  def load_contractor
    @contractor = Contractor.find(params[:id])
  end

  def contractor_params
    params.require(:contractor).permit(:first_name, :last_name, :trade, :phone, :bank_name,
      :bank_account_number, :bank_account_name, :note, :active)
  end
end
