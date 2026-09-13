class BoqItemsController < BoqWorkspaceController
  before_action :load_categories

  def new
    @item = BoqItem.new(boq_category: @categories.first)
  end

  def create
    category = @categories.find(params.require(:boq_item)[:boq_category_id])
    @item = category.boq_items.new(item_params)
    @item.save ? saved_response("เพิ่มรายการ BOQ แล้ว") : render(:new, status: :unprocessable_entity)
  end

  def edit
    @item = @master.boq_items.find(params[:id])
  end

  def update
    @item = @master.boq_items.find(params[:id])
    @item.update(item_params) ? saved_response("บันทึกรายการและคำนวณยอดใหม่แล้ว") : render(:edit, status: :unprocessable_entity)
  rescue ActiveRecord::StaleObjectError
    @item.reload
    @item.errors.add(:base, "รายการถูกแก้ไขโดยผู้อื่นแล้ว กรุณาตรวจข้อมูลล่าสุดก่อนบันทึกอีกครั้ง")
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @item = @master.boq_items.find(params[:id])
    @item.destroy ? saved_response("ลบรายการ BOQ แล้ว") : render(:edit, status: :unprocessable_entity)
  end

  private

  def load_categories
    @categories = @master.boq_categories
  end

  def item_params
    params.require(:boq_item).permit(:code, :name, :unit, :material_quantity,
      :material_unit_price, :labor_unit_price, :progress_percentage, :contractor_name, :note, :lock_version)
  end
end
