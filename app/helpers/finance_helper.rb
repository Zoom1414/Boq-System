module FinanceHelper
  STATUS_LABELS = { "draft" => "ฉบับร่าง", "pending_pu" => "รอจัดซื้อ", "pending" => "รออนุมัติ", "approved" => "อนุมัติแล้ว", "rejected" => "ปฏิเสธ" }.freeze
  THAI_MONTHS = %w[มกราคม กุมภาพันธ์ มีนาคม เมษายน พฤษภาคม มิถุนายน กรกฎาคม สิงหาคม กันยายน ตุลาคม พฤศจิกายน ธันวาคม].freeze

  def workspace_params
    { project_id: @nav_project&.id, house_plan_id: @nav_plan&.id }
  end

  def finance_status(document)
    tag.span(STATUS_LABELS.fetch(document.status), class: "status-pill status-#{document.status}")
  end

  def document_number(document)
    document.is_a?(PurchaseOrder) ? document.po_number : document.dv_number
  end

  def document_amount(document)
    document.is_a?(PurchaseOrder) ? document.grand_total : document.total_requested_amount
  end

  def document_vendor(document)
    document.is_a?(PurchaseOrder) ? document.vendor_name : document.contractor_name
  end

  def thai_date(date)
    date ? "#{date.day}/#{date.month}/#{date.year + 543}" : "—"
  end

  def thai_month(date)
    "#{THAI_MONTHS[date.month - 1]} #{date.year + 543}"
  end

  def item_picker_options(items)
    items.map do |item|
      [ "#{item.code} · #{item.name}", item.id,
        { "data-name" => item.name, "data-unit" => item.unit, "data-material" => item.material_unit_price,
          "data-labor" => item.labor_unit_price, "data-remaining" => item.material_remaining_qty,
          "data-labor-remaining" => item.labor_remaining_amount } ]
    end
  end

  def workspace_nav(label, path, active, icon = :grid)
    link_to path, class: "workspace-nav-link #{'is-active' if active}", aria: { current: active ? "page" : nil } do
      safe_join([ ui_icon(icon, css: "size-4"), tag.span(label) ])
    end
  end
end
