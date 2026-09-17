class LoginEvent < ApplicationRecord
  REASONS = { "invalid" => "อีเมลหรือรหัสผ่านไม่ถูกต้อง", "not_found_in_database" => "ไม่พบบัญชีนี้",
    "inactive" => "บัญชีถูกปิดใช้งาน", "locked" => "บัญชีถูกล็อก" }.freeze

  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :today, -> { where(created_at: Time.current.all_day) }

  def self.record(user: nil, email:, success:, request:, reason: nil)
    create!(user: user, email: email.to_s.strip.downcase.first(255), success: success, reason: reason&.to_s,
      ip_address: request&.remote_ip, user_agent: request&.user_agent.to_s.first(255))
  rescue StandardError => error
    Rails.logger.warn("[LoginEvent] #{error.class}: #{error.message}")
    nil
  end

  def reason_label
    REASONS.fetch(reason.to_s, reason.presence || "ไม่สำเร็จ")
  end
end
