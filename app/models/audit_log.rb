class AuditLog < ApplicationRecord
  HIDDEN_FIELDS = %w[updated_at created_at lock_version encrypted_password reset_password_token reset_password_sent_at remember_created_at].freeze
  # Balances change through approved documents, which are logged on their own.
  BOQ_COMPUTED_FIELDS = %w[material_total labor_total material_remaining_qty labor_remaining_amount material_used_qty labor_paid_amount].freeze
  ACTIONS = {
    "po_create" => [ "สร้าง PO", "amber" ], "pu_complete" => [ "บันทึก PU", "green" ], "po_reject" => [ "ปฏิเสธ PO", "red" ], "po_update" => [ "แก้ไข PO", "slate" ],
    "dv_create" => [ "เบิกค่าแรง DV", "purple" ], "dv_approve" => [ "อนุมัติ DV", "green" ], "dv_reject" => [ "ปฏิเสธ DV", "red" ],
    "dv_cancel" => [ "ยกเลิก DV", "red" ], "dv_update" => [ "แก้ไข DV", "slate" ],
    "boq_create" => [ "เพิ่มรายการ BOQ", "blue" ], "boq_update" => [ "แก้ไข BOQ", "blue" ], "boq_destroy" => [ "ลบรายการ BOQ", "red" ],
    "category_create" => [ "เพิ่มหมวดงาน", "blue" ], "category_update" => [ "แก้ไขหมวดงาน", "blue" ], "category_destroy" => [ "ลบหมวดงาน", "red" ],
    "master_create" => [ "สร้าง Master BOQ", "blue" ],
    "contractor_create" => [ "เพิ่มช่าง", "gold" ], "contractor_update" => [ "แก้ไขข้อมูลช่าง", "gold" ], "contractor_destroy" => [ "ลบช่าง", "red" ],
    "project_create" => [ "สร้างโครงการ", "slate" ], "project_update" => [ "แก้ไขโครงการ", "slate" ], "project_destroy" => [ "ลบโครงการ", "red" ],
    "plan_create" => [ "เพิ่มแปลนบ้าน", "slate" ], "plan_update" => [ "แก้ไขแปลนบ้าน", "slate" ], "plan_destroy" => [ "ลบแปลนบ้าน", "red" ],
    "user_create" => [ "เพิ่มผู้ใช้", "purple" ], "user_update" => [ "แก้ไขผู้ใช้", "purple" ], "user_destroy" => [ "ลบผู้ใช้", "red" ],
    "setting_update" => [ "ตั้งค่าระบบ", "dark" ]
  }.freeze

  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :today, -> { where(created_at: Time.current.all_day) }

  def self.capture(record, event)
    details = event == "update" ? visible_changes(record) : {}
    return if event == "update" && details.empty?

    action, summary = describe(record, event, details)
    return unless action

    create!(user: Current.user, action: action, auditable_type: record.class.name, auditable_id: record.id,
      summary: summary.to_s.first(1000), details: details)
  rescue StandardError => error
    Rails.logger.warn("[AuditLog] #{error.class}: #{error.message}")
    nil
  end

  def self.visible_changes(record)
    changes = record.saved_changes.except(*HIDDEN_FIELDS)
    changes = changes.except(*BOQ_COMPUTED_FIELDS) if record.is_a?(BoqItem) || record.is_a?(MasterBoq)
    changes.transform_values do |(before, after)|
      [ before, after ].map { |value| record.is_a?(Contractor) && value.is_a?(String) && value.match?(/\A\d{10,15}\z/) ? "•••#{value.last(4)}" : value }
    end.transform_values { |pair| pair.map { |v| v.is_a?(BigDecimal) ? v.to_s("F") : v } }
  end

  def self.money(value)
    ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", value.to_d))
  end

  def self.field_list(details)
    details.map { |field, (before, after)| "#{field}: #{before.presence || '—'} → #{after.presence || '—'}" }.first(6).join(", ")
  end

  def self.describe(record, event, details)
    case record
    when PurchaseOrder
      status = details["status"]&.last
      if event == "create" then [ "po_create", "สร้าง PO #{record.po_number} | ผู้รับเหมา: #{record.vendor_name} | จำนวน #{record.po_items.size} รายการ" ]
      elsif status == "approved" then [ "pu_complete", "บันทึก #{record.pu_number} | อ้างอิง PO #{record.po_number} | ผู้รับเหมา: #{record.vendor_name} | ยอด #{money(record.grand_total)} บาท" ]
      elsif status == "rejected" then [ "po_reject", "ปฏิเสธ PO #{record.po_number} | เหตุผล: #{record.admin_note}" ]
      else [ "po_update", "แก้ไข PO #{record.po_number} | #{field_list(details)}" ]
      end
    when LaborDrawRequest
      status = details["status"]&.last
      base = "#{record.dv_number} | ช่าง/ผู้รับเหมา: #{record.contractor_name} | ยอดรวม #{money(record.total_requested_amount)} บาท"
      if event == "create" then [ "dv_create", "เบิกค่าแรง #{base} | #{record.labor_draw_items.size} รายการ" ]
      elsif status == "approved" then [ "dv_approve", "อนุมัติ #{base}#{" | อนุมัติเกินงบ: #{record.override_reason}" if record.budget_override?}" ]
      elsif status == "rejected" then [ "dv_reject", "ปฏิเสธ #{base} | เหตุผล: #{record.admin_note}" ]
      elsif status == "cancelled" then [ "dv_cancel", "ยกเลิก #{base} | เหตุผล: #{record.cancel_reason}" ]
      else [ "dv_update", "แก้ไข #{record.dv_number} | #{field_list(details)}" ]
      end
    when BoqItem
      [ "boq_#{event}", "#{{ 'create' => 'เพิ่ม', 'update' => 'แก้ไข', 'destroy' => 'ลบ' }[event]} #{record.code} #{record.name}#{" | #{field_list(details)}" if details.any?}" ]
    when BoqCategory
      [ "category_#{event}", "หมวดงาน #{record.name}#{" | #{field_list(details)}" if details.any?}" ]
    when MasterBoq
      event == "create" ? [ "master_create", "สร้าง Master BOQ แปลน #{record.house_plan&.name}" ] : nil
    when Contractor
      [ "contractor_#{event}", "#{record.full_name}#{" | #{field_list(details)}" if details.any?}" ]
    when Project
      [ "project_#{event}", "#{record.code} #{record.name}#{" | #{field_list(details)}" if details.any?}" ]
    when HousePlan
      [ "plan_#{event}", "#{record.name} (#{record.project&.name})#{" | #{field_list(details)}" if details.any?}" ]
    when User
      [ "user_#{event}", "#{record.name} <#{record.email}> role: #{record.role}#{" | #{field_list(details)}" if details.any?}" ]
    when SystemSetting
      [ "setting_update", "#{SystemSetting::LABELS.fetch(record.key, record.key)}: #{details.dig('value', 0).presence || SystemSetting::DEFAULTS[record.key]} → #{record.value}" ]
    end
  end

  def action_label
    ACTIONS.dig(action, 0) || action
  end

  def action_tone
    ACTIONS.dig(action, 1) || "slate"
  end
end
