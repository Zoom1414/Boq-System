class HousePlansController < ApplicationController
  before_action -> { authorize HousePlan }
  def index
    @project = Project.find(params[:project_id])
    @house_plans = @project.house_plans.includes(:master_boq).order(created_at: :desc, id: :desc)
  end

  def new
    @project = Project.find(params[:project_id])
    @house_plan = @project.house_plans.new
  end

  def create
    @project = Project.find(params[:project_id])

    @house_plan = @project.house_plans.new(house_plan_params)

    if @house_plan.save
      redirect_to project_house_plans_path(@project)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @project = Project.find(params[:project_id])
    @house_plan = @project.house_plans.find(params[:id])
  end

  def update
    @project = Project.find(params[:project_id])
    @house_plan = @project.house_plans.find(params[:id])

    if @house_plan.update(house_plan_params)
      redirect_to project_house_plans_path(@project)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = Project.find(params[:project_id])
    @house_plan = @project.house_plans.find(params[:id])

    if @house_plan.destroy
      redirect_to project_house_plans_path(@project), notice: "ลบแปลนบ้านเรียบร้อยแล้ว", status: :see_other
    else
      redirect_to project_house_plans_path(@project), alert: @house_plan.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def house_plan_params
    params.require(:house_plan).permit(:name, :plan_code)
  end
end
