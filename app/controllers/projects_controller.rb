class ProjectsController < ApplicationController
  before_action -> { authorize Project }
  def index
    @projects = Project.includes(:house_plans).order(created_at: :desc, id: :desc)
    @project_budgets = MasterBoq.joins(:house_plan).group("house_plans.project_id")
      .sum("total_material_budget + total_labor_budget")
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to projects_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @project = Project.find(params[:id])
  end

  def edit
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])

    if @project.update(project_params)
      redirect_to projects_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = Project.find(params[:id])
    if @project.destroy
      redirect_to projects_path, notice: "ลบโครงการเรียบร้อยแล้ว", status: :see_other
    else
      redirect_to project_path(@project), alert: @project.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def project_params
    params.require(:project).permit(:name, :code, :location, :status, :description)
  end
end
