class BoqCategoriesController < BoqWorkspaceController
  def new
    @category = @master.boq_categories.new(position: (@master.boq_categories.maximum(:position) || 0) + 1)
  end

  def create
    @category = @master.boq_categories.new(category_params)
    @category.save ? saved_response("เพิ่มหมวดงานแล้ว") : render(:new, status: :unprocessable_entity)
  end

  def edit
    @category = @master.boq_categories.find(params[:id])
  end

  def update
    @category = @master.boq_categories.find(params[:id])
    @category.update(category_params) ? saved_response("บันทึกหมวดงานแล้ว") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @category = @master.boq_categories.find(params[:id])
    @category.destroy ? saved_response("ลบหมวดงานแล้ว") : render(:edit, status: :unprocessable_entity)
  end

  private

  def category_params
    params.require(:boq_category).permit(:name, :position)
  end
end
