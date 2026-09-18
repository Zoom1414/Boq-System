module FinanceHelper
  STATUS_LABELS = { "draft" => "ฉบับร่าง", "pending_pu" => "รอจัดซื้อ", "pending" => "รออนุมัติ", "approved" => "อนุมัติแล้ว", "rejected" => "ปฏิเสธ", "cancelled" => "ยกเลิก" }.freeze
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
    link_to path, class: "workspace-nav-link #{'is-active' if active}", aria: { current: active ? "page" : nil },
      data: { turbo_frame: "workspace_content", workspace_navigation_target: "link" } do
      safe_join([ ui_icon(icon, css: "size-4"), tag.span(label) ])
    end
  end

  def workspace_page_path
    case controller_name
    when "dashboard" then dashboard_path
    when "master_boqs", "boq_items", "boq_categories" then master_boq_path
    when "purchase_orders"
      case action_name
      when "new", "create" then new_purchase_order_path
      when "pending", "procure", "complete" then pending_purchase_orders_path
      when "history" then history_purchase_orders_path
      else purchase_orders_path
      end
    when "labor_draw_requests"
      %w[new create].include?(action_name) ? new_labor_draw_request_path : labor_draw_requests_path
    when "approvals" then approvals_path
    when "contractors" then contractors_path
    when "developer_panel" then request.path
    else projects_path
    end
  end
end
