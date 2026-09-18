require "csv"

class DeveloperPanelController < ApplicationController
  ROLES = %w[dev admin project_engineer user].freeze
  PERMISSIONS = [
    [ "ดูภาพรวม, Master BOQ, เอกสาร และ Export", { "dev" => :yes, "admin" => :yes, "project_engineer" => :yes, "user" => :yes } ],
    [ "แก้ไข Master BOQ (ในตาราง/ฟอร์ม) และ Import CSV", { "dev" => :no, "admin" => :yes, "project_engineer" => :no, "user" => :no } ],
    [ "สร้าง/แก้ไขโครงการและแปลนบ้าน", { "dev" => :yes, "admin" => :yes, "project_engineer" => :engineer_can_manage_projects, "user" => :no } ],
    [ "เปิดใบสั่งซื้อ / สั่งจ้าง (PO)", { "dev" => :no, "admin" => :yes, "project_engineer" => :yes, "user" => :no } ],
    [ "ส่งใบเบิกค่าแรง (DV)", { "dev" => :no, "admin" => :yes, "project_engineer" => :yes, "user" => :no } ],
    [ "Admin เบิก DV แล้วอนุมัติทันที", { "dev" => :no, "admin" => :admin_instant_labor_approval, "project_engineer" => :no, "user" => :no } ],
    [ "อนุมัติ / ปฏิเสธ PO, PU และ DV", { "dev" => :no, "admin" => :yes, "project_engineer" => :no, "user" => :no } ],
    [ "อนุมัติเกินงบ (Override)", { "dev" => :no, "admin" => :allow_budget_override, "project_engineer" => :no, "user" => :no } ],
    [ "เพิ่ม/แก้ไขทะเบียนช่าง และเห็นเลขบัญชีเต็ม", { "dev" => :no, "admin" => :yes, "project_engineer" => :no, "user" => :no } ],
    [ "Developer Panel: ผู้ใช้, Log, ยกเลิก DV, ตั้งค่าระบบ", { "dev" => :yes, "admin" => :no, "project_engineer" => :no, "user" => :no } ],
    [ "เข้าใช้งานขณะปิดปรับปรุงระบบ", { "dev" => :yes, "admin" => :yes, "project_engineer" => :no, "user" => :no } ]
  ].freeze

  before_action :require_developer
  before_action :load_header_counts

  def overview
    @page_title = "Developer Panel"
    @stats = { users: User.count, active: User.where(active: true).count, logins_today: LoginEvent.where(success: true).today.count,
      actions_today: AuditLog.today.count, projects: Project.count }
    @failed_today = LoginEvent.where(success: false).today.count
    @recent_logins = LoginEvent.includes(:user).recent.limit(8)
    @recent_actions = AuditLog.includes(:user).recent.limit(8)
  end

  def users
    @page_title = "จัดการผู้ใช้"
    @query = params[:q].to_s.squish
    scope = User.order(:role, :name)
    scope = scope.where("users.name ILIKE :q OR users.email ILIKE :q", q: "%#{User.sanitize_sql_like(@query)}%") if @query.present?
    scope = scope.where(role: params[:role]) if ROLES.include?(params[:role])
    @users = scope.to_a
    @last_logins = LoginEvent.where(success: true, user_id: @users.map(&:id)).group(:user_id).maximum(:created_at)
    @new_user ||= User.new(role: "project_engineer", active: true)
  end

  def create_user
    @new_user = User.new(user_params)
    if @new_user.save
      redirect_to developer_users_path, notice: "เพิ่มผู้ใช้ #{@new_user.email} แล้ว", status: :see_other
    else
      users
      @open_form = true
      render :users, status: :unprocessable_entity
    end
  end

  def update_user
    user = User.find(params[:id])
    attributes = user_params
    attributes.delete(:password) if attributes[:password].blank?
    if user == current_user && (attributes[:role].present? && attributes[:role] != "dev" || attributes[:active] == "0")
      return redirect_to developer_users_path, alert: "ไม่สามารถลดสิทธิ์หรือปิดบัญชีของตัวเองได้", status: :see_other
    end
    if user.update(attributes)
      redirect_to developer_users_path, notice: "บันทึกผู้ใช้ #{user.email} แล้ว", status: :see_other
    else
      redirect_to developer_users_path, alert: "บันทึกไม่สำเร็จ: #{user.errors.full_messages.to_sentence}", status: :see_other
    end
  end

  def projects
    @page_title = "จัดการโครงการ"
    @projects = Project.includes(:house_plans).order(:name).to_a
    budgets = MasterBoq.joins(:house_plan).group("house_plans.project_id").sum("total_material_budget + total_labor_budget")
    po_spent = PurchaseOrder.approved.group(:project_id).sum(:grand_total)
    dv_spent = LaborDrawRequest.approved.group(:project_id).sum(:total_requested_amount)
    pending = PurchaseOrder.pending_pu.group(:project_id).count
    LaborDrawRequest.pending.group(:project_id).count.each { |id, count| pending[id] = pending.fetch(id, 0) + count }
    @rows = @projects.map do |project|
      budget = budgets.fetch(project.id, 0)
      spent = po_spent.fetch(project.id, 0) + dv_spent.fetch(project.id, 0)
      { project: project, budget: budget, spent: spent, pending: pending.fetch(project.id, 0),
        used: budget.to_d.positive? ? (spent.to_d / budget * 100).round(1) : 0 }
    end
  end

  def logins
    @page_title = "ประวัติ Login"
    @query = params[:q].to_s.squish
    @result = params[:result].presence_in(%w[success failed])
    scope = LoginEvent.includes(:user).recent
    scope = scope.where("login_events.email ILIKE ?", "%#{LoginEvent.sanitize_sql_like(@query)}%") if @query.present?
    scope = scope.where(success: @result == "success") if @result
    @events = scope.limit(300)
    @summary = { today: LoginEvent.where(success: true).today.count, failed: LoginEvent.where(success: false).today.count,
      week: LoginEvent.where(success: true, created_at: 7.days.ago..).count }
  end

  def audit
    @page_title = "Audit Log"
    @query = params[:q].to_s.squish
    @action = params[:log_action].presence_in(AuditLog::ACTIONS.keys)
    @user_id = params[:user_id].presence
    scope = AuditLog.includes(:user).recent
    scope = scope.where("audit_logs.summary ILIKE ?", "%#{AuditLog.sanitize_sql_like(@query)}%") if @query.present?
    scope = scope.where(action: @action) if @action
    scope = scope.where(user_id: @user_id) if @user_id
    scope = scope.where(created_at: Date.parse(params[:from]).beginning_of_day..) if params[:from].present?
    scope = scope.where(created_at: ..Date.parse(params[:to]).end_of_day) if params[:to].present?
    @logs = scope.limit(300)
    @users = User.order(:name)
  rescue Date::Error
    redirect_to developer_audit_path, alert: "รูปแบบวันที่ไม่ถูกต้อง", status: :see_other
  end

  def permissions
    @page_title = "สิทธิ์การเข้าถึง"
    @role_counts = User.group(:role).count
  end

  def approvals
    @page_title = "ตั้งค่าอนุมัติ"
  end

  def update_approvals
    SystemSetting.update_values!(settings_params(%w[allow_budget_override admin_instant_labor_approval engineer_can_manage_projects]))
    redirect_to developer_approvals_path, notice: "บันทึกการตั้งค่าอนุมัติแล้ว", status: :see_other
  end

  def cancellations
    @page_title = "ยกเลิกใบเบิก DV"
    @status = params[:status].presence_in(%w[pending approved cancelled]) || "pending"
    @query = params[:q].to_s.squish
    scope = LaborDrawRequest.includes(:project, :house_plan, :user, :cancelled_by, :labor_draw_items).where(status: @status)
    if @query.present?
      scope = scope.where("labor_draw_requests.dv_number ILIKE :q OR labor_draw_requests.contractor_name ILIKE :q", q: "%#{LaborDrawRequest.sanitize_sql_like(@query)}%")
    end
    @draws = scope.order(created_at: :desc).limit(200)
    @counts = LaborDrawRequest.group(:status).count
  end

  def cancel_draw
    draw = LaborDrawRequest.find(params[:id])
    was_approved = draw.approved?
    CancelLaborDrawService.new(draw, actor: current_user, reason: params[:cancel_reason]).call
    message = was_approved ? "ยกเลิก #{draw.dv_number} และคืนยอดค่าแรงเข้า Master BOQ แล้ว" : "ยกเลิก #{draw.dv_number} แล้ว"
    redirect_to developer_cancellations_path(status: "cancelled"), notice: message, status: :see_other
  rescue CancelLaborDrawService::InvalidState, ActiveRecord::RecordInvalid => error
    redirect_to developer_cancellations_path(status: draw&.status), alert: "ยกเลิกไม่สำเร็จ: #{error.message}", status: :see_other
  end

  def notifications
    @page_title = "การแจ้งเตือน"
  end

  def update_notifications
    SystemSetting.update_values!(settings_params(%w[announcement_active announcement_level announcement_message]))
    redirect_to developer_notifications_path, notice: "บันทึกประกาศแล้ว", status: :see_other
  end

  def system_control
    @page_title = "ควบคุมระบบ"
    @info = {
      "Environment" => Rails.env, "Rails" => Rails.version, "Ruby" => RUBY_VERSION,
      "Database" => ActiveRecord::Base.connection.current_database,
      "ขนาดฐานข้อมูล" => ActiveRecord::Base.connection.select_value("SELECT pg_size_pretty(pg_database_size(current_database()))"),
      "เวลาเซิร์ฟเวอร์" => I18n.l(Time.current, format: "%d/%m/%Y %H:%M")
    }
    @tables = { "ผู้ใช้" => User, "โครงการ" => Project, "แปลนบ้าน" => HousePlan, "รายการ BOQ" => BoqItem, "PO" => PurchaseOrder,
      "DV" => LaborDrawRequest, "ช่าง" => Contractor, "Audit Log" => AuditLog, "Login Log" => LoginEvent }.transform_values(&:count)
  end

  def update_system
    SystemSetting.update_values!(settings_params(%w[maintenance_mode maintenance_message]))
    redirect_to developer_system_path, notice: SystemSetting.enabled?(:maintenance_mode) ? "เปิดโหมดปิดปรับปรุงแล้ว" : "บันทึกการควบคุมระบบแล้ว", status: :see_other
  end

  def export
    rows, headers = case params[:dataset]
    when "users"
      [ User.order(:id).map { |u| [ u.id, u.name, u.email, u.role, u.active? ? "active" : "inactive", u.created_at ] }, %w[id name email role status created_at] ]
    when "logins"
      [ LoginEvent.recent.limit(5000).map { |e| [ e.created_at, e.email, e.success ? "success" : "failed", e.reason, e.ip_address, e.user_agent ] }, %w[time email result reason ip user_agent] ]
    when "audit"
      [ AuditLog.includes(:user).recent.limit(5000).map { |l| [ l.created_at, l.user&.email, l.action, l.auditable_type, l.auditable_id, l.summary ] }, %w[time user action type record_id summary] ]
    else
      raise ActionController::RoutingError, "Unknown dataset"
    end
    csv = CSV.generate { |out| out << headers; rows.each { |row| out << row.map { |v| v.is_a?(String) && v.match?(/\A[=+\-@]/) ? "'#{v}" : v } } }
    send_data "﻿#{csv}", filename: "sitework-#{params[:dataset]}-#{Time.current.strftime('%Y%m%d-%H%M')}.csv", type: "text/csv; charset=utf-8"
  end

  private

  def require_developer
    head :forbidden unless current_user&.dev?
  end

  def load_header_counts
    @pending_pu = PurchaseOrder.pending_pu.count
    @pending_dv = LaborDrawRequest.pending.count
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :active, :password).tap do |attrs|
      attrs.delete(:role) unless ROLES.include?(attrs[:role])
    end
  end

  def settings_params(keys)
    params.fetch(:settings, {}).permit(*keys).to_h
  end
end
