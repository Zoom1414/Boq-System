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
    return inline_update if params[:inline].present?

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

  # Admin edits a single cell in the worksheet: save, then refresh only the computed cells
  # so the cell being typed in next is never replaced.
  def inline_update
    if @item.update(item_params)
      load_worksheet
      @item.reload
      render turbo_stream: inline_cell_streams + [ inline_status("บันทึก #{@item.code} แล้ว ✓") ]
    else
      message = @item.errors.full_messages.to_sentence
      load_worksheet
      @item.reload
      render turbo_stream: [ inline_row_stream, inline_status("บันทึกไม่สำเร็จ: #{message}", error: true) ], status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    load_worksheet
    @item.reload
    render turbo_stream: [ inline_row_stream, inline_status("รายการนี้ถูกแก้ไขโดยผู้อื่นแล้ว ระบบโหลดค่าล่าสุดให้ กรุณาตรวจสอบอีกครั้ง", error: true) ], status: :conflict
  end

  def inline_cell_streams
    dom = "boq-item-#{@item.id}"
    h = helpers
    cells = {
      "material_total" => [ h.boq_money(@item.material_total), "boq-numeric boq-total" ],
      "material_remaining" => [ h.boq_qty(@item.material_remaining_qty), "boq-numeric #{@item.material_remaining_qty.negative? ? 'boq-red' : 'boq-positive'}" ],
      "labor_total" => [ h.boq_money(@item.labor_total), "boq-numeric boq-total" ],
      "labor_remaining" => [ h.boq_money(@item.labor_remaining_amount), "boq-numeric #{@item.labor_remaining_amount.negative? ? 'boq-red' : 'boq-positive'}" ]
    }
    category = @categories.find { |c| c.id == @item.boq_category_id }
    [
      turbo_stream.replace("#{dom}-lock", h.hidden_field_tag("boq_item[lock_version]", @item.lock_version, id: "#{dom}-lock", data: { inline_field: true })),
      *cells.map { |key, (text, css)| turbo_stream.replace("#{dom}-#{key}", h.tag.td(text, id: "#{dom}-#{key}", class: css)) },
      turbo_stream.replace("#{dom}-progress", h.boq_progress_cell(@item.completion_percentage, id: "#{dom}-progress")),
      turbo_stream.replace("boq-category-#{category.id}-progress", h.boq_progress_cell(BoqProgressSummary.percentage(category.boq_items.to_a), id: "boq-category-#{category.id}-progress")),
      turbo_stream.replace("boq-master-progress", h.boq_progress_cell(BoqProgressSummary.percentage(@categories.flat_map(&:boq_items)), id: "boq-master-progress")),
      turbo_stream.replace("boq-totals", partial: "master_boqs/totals"),
      turbo_stream.replace("boq-summary", partial: "master_boqs/summary")
    ]
  end

  def inline_row_stream
    contractors = Contractor.active.or(Contractor.where(id: @item.contractor_id)).order(:full_name).to_a
    turbo_stream.replace("boq-item-#{@item.id}", partial: "master_boqs/item_row",
      locals: { item: @item, row_number: params[:row_number].to_i, editable: true, contractors: contractors })
  end

  def inline_status(message, error: false)
    turbo_stream.replace("boq-inline-status", helpers.tag.span(message, id: "boq-inline-status",
      class: "boq-inline-status #{error ? 'is-error' : 'is-ok'}", role: "status", aria: { live: "polite" }))
  end

  def load_categories
    @categories = @master.boq_categories
  end

  def item_params
    params.require(:boq_item).permit(:code, :name, :unit, :material_quantity,
      :material_unit_price, :labor_unit_price, :contractor_id, :note, :lock_version)
  end
end
