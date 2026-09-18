class SystemSetting < ApplicationRecord
  include Auditable

  DEFAULTS = {
    "allow_budget_override" => "true",
    "admin_instant_labor_approval" => "true",
    "engineer_can_manage_projects" => "true",
    "maintenance_mode" => "false",
    "maintenance_message" => "ระบบกำลังปิดปรับปรุงชั่วคราว กรุณากลับมาใหม่ภายหลัง",
    "announcement_active" => "false",
    "announcement_level" => "info",
    "announcement_message" => ""
  }.freeze
  BOOLEAN_KEYS = %w[allow_budget_override admin_instant_labor_approval engineer_can_manage_projects maintenance_mode announcement_active].freeze
  LEVELS = %w[info warning danger].freeze
  LABELS = {
    "allow_budget_override" => "อนุญาตให้ Admin อนุมัติเกินงบ",
    "admin_instant_labor_approval" => "Admin เบิกค่าแรงแล้วอนุมัติทันที",
    "engineer_can_manage_projects" => "วิศวกรสร้าง/แก้ไขโครงการและแปลนบ้านได้",
    "maintenance_mode" => "โหมดปิดปรับปรุงระบบ",
    "maintenance_message" => "ข้อความปิดปรับปรุง",
    "announcement_active" => "แสดงประกาศ",
    "announcement_level" => "ระดับประกาศ",
    "announcement_message" => "ข้อความประกาศ"
  }.freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: DEFAULTS.keys }

  def self.value(key)
    Current.settings ||= pluck(:key, :value).to_h
    Current.settings.fetch(key.to_s) { DEFAULTS.fetch(key.to_s) }.to_s
  end

  def self.enabled?(key)
    value(key) == "true"
  end

  def self.update_values!(values)
    transaction do
      values.each do |key, raw|
        key = key.to_s
        next unless DEFAULTS.key?(key)

        value = BOOLEAN_KEYS.include?(key) ? ActiveModel::Type::Boolean.new.cast(raw).to_s : raw.to_s.strip
        value = "info" if key == "announcement_level" && !LEVELS.include?(value)
        setting = find_or_initialize_by(key: key)
        setting.update!(value: value) if setting.new_record? || setting.value != value
      end
    end
    Current.settings = nil
  end
end
