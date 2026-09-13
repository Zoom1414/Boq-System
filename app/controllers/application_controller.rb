class ApplicationController < ActionController::Base
  include Pundit::Authorization
  before_action :authenticate_user!
  before_action :load_navigation, unless: :devise_controller?
  layout :workspace_layout

  rescue_from Pundit::NotAuthorizedError do
    head :forbidden
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def workspace_layout
    devise_controller? ? "application" : "boq"
  end

  def load_navigation
    @nav_projects = Project.order(:name)
    project_id = params[:project_id].presence || session[:project_id]
    @nav_project = @nav_projects.find_by(id: project_id) || @nav_projects.first
    @nav_plans = @nav_project ? @nav_project.house_plans.order(:name) : HousePlan.none
    plan_id = params[:house_plan_id].presence || session[:house_plan_id]
    @nav_plan = @nav_plans.find_by(id: plan_id) || @nav_plans.first
    session[:project_id] = @nav_project&.id
    session[:house_plan_id] = @nav_plan&.id
  end
end
