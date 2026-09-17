module BoqHelper
  def boq_qty(value)
    number_with_precision(value || 0, precision: 4, strip_insignificant_zeros: true, delimiter: ",")
  end

  def boq_money(value)
    number_with_precision(value || 0, precision: 2, delimiter: ",")
  end

  # Raw value for an <input>, without thousands separators.
  def boq_input_number(value, precision)
    number_with_precision(value || 0, precision: precision, strip_insignificant_zeros: true)
  end

  # An inline-editable worksheet cell (Admin only). Saved by the boq-inline Stimulus controller.
  def boq_cell_input(item, field, value, css: "", number: false, step: nil)
    options = { id: "boq-item-#{item.id}-#{field}", class: "boq-cell-input #{css}", autocomplete: "off",
      aria: { label: "#{item.code} #{field}" },
      data: { inline_field: true, original: value, action: "change->boq-inline#save keydown->boq-inline#key" } }
    if number
      number_field_tag("boq_item[#{field}]", value, options.merge(step: step, min: 0, inputmode: "decimal"))
    else
      text_field_tag("boq_item[#{field}]", value, options)
    end
  end

  def boq_progress_cell(percentage, id:)
    pct = percentage.to_d
    tag.div(id: id, class: "boq-pct #{'is-over' if pct > 100} #{'is-done' if pct >= 100 && pct <= 100}",
      title: "วัสดุที่ใช้แล้ว #{pct}% ของปริมาณตาม BOQ") do
      safe_join([ tag.span(tag.i(style: "width:#{pct.clamp(0, 100)}%")), tag.b("#{pct}%") ])
    end
  end
end
