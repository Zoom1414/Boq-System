class Contractor < ApplicationRecord
  include Auditable
  BANKS = [
    "ธนาคารกรุงเทพ", "ธนาคารกสิกรไทย", "ธนาคารกรุงไทย", "ธนาคารไทยพาณิชย์", "ธนาคารกรุงศรีอยุธยา",
    "ธนาคารทหารไทยธนชาต (ttb)", "ธนาคารออมสิน", "ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร (ธ.ก.ส.)",
    "ธนาคารอาคารสงเคราะห์", "ธนาคารยูโอบี", "ธนาคารซีไอเอ็มบี ไทย", "ธนาคารเกียรตินาคินภัทร",
    "ธนาคารแลนด์ แอนด์ เฮ้าส์", "ธนาคารทิสโก้", "ธนาคารอิสลามแห่งประเทศไทย", "พร้อมเพย์ (PromptPay)"
  ].freeze

  has_many :boq_items, dependent: :restrict_with_error
  has_many :labor_draw_requests, dependent: :restrict_with_error

  normalizes :first_name, :last_name, :trade, :phone, :bank_name, :bank_account_name,
    with: ->(value) { value.to_s.squish.presence }
  normalizes :note, with: ->(value) { value.to_s.strip.presence }
  normalizes :bank_account_number, with: ->(value) { value.to_s.gsub(/\D/, "").presence }

  before_validation :build_full_name
  after_update :sync_boq_item_names, if: :saved_change_to_full_name?

  validates :first_name, presence: { message: "ต้องระบุ" }
  validates :full_name, uniqueness: { case_sensitive: false, message: "ซ้ำกับช่างที่มีอยู่แล้วในทะเบียน" }
  validates :bank_name, inclusion: { in: BANKS, message: "ไม่อยู่ในรายการ" }, allow_nil: true
  validates :bank_account_number, format: { with: /\A\d{10,15}\z/, message: "ต้องเป็นตัวเลข 10–15 หลัก" }, allow_nil: true
  validate :bank_account_not_used_by_another_contractor
  validate :bank_details_complete

  scope :active, -> { where(active: true) }
  scope :bank_incomplete, -> { where(bank_name: nil).or(where(bank_account_number: nil)).or(where(bank_account_name: nil)) }
  scope :search, lambda { |query|
    query = query.to_s.squish
    next all if query.blank?

    like = "%#{sanitize_sql_like(query)}%"
    digits = query.gsub(/\D/, "")
    conditions = where("contractors.full_name ILIKE :q OR contractors.trade ILIKE :q OR contractors.phone ILIKE :q OR contractors.bank_account_name ILIKE :q", q: like)
    digits.length >= 3 ? conditions.or(where("contractors.bank_account_number LIKE ?", "%#{digits}%")) : conditions
  }

  def self.find_by_name(name)
    name = name.to_s.squish
    name.blank? ? nil : where("lower(full_name) = ?", name.downcase).first
  end

  # Used by CSV import and legacy name-based data: link to the registry, registering new names.
  def self.resolve_name!(name)
    find_by_name(name) || create!(first_name: name.to_s.squish)
  rescue ActiveRecord::RecordNotUnique
    find_by_name(name) || raise
  end

  def bank_ready?
    bank_name.present? && bank_account_number.present? && bank_account_name.present?
  end

  def display_label
    trade.present? ? "#{full_name} · #{trade}" : full_name
  end

  private

  def build_full_name
    self.full_name = [ first_name, last_name ].compact.join(" ").presence
  end

  def bank_account_not_used_by_another_contractor
    return if bank_account_number.blank?

    owner = Contractor.where(bank_account_number: bank_account_number).where.not(id: id).first
    errors.add(:bank_account_number, "นี้ถูกใช้กับ “#{owner.full_name}” แล้ว — หนึ่งบัญชีใช้ได้กับช่างเพียงคนเดียวเพื่อป้องกันการจ่ายซ้ำ") if owner
  end

  def bank_details_complete
    fields = [ bank_name, bank_account_number, bank_account_name ]
    return if fields.all?(&:present?) || fields.none?(&:present?)

    errors.add(:base, "กรอกข้อมูลบัญชีให้ครบทั้งธนาคาร เลขบัญชี และชื่อบัญชี")
  end

  def sync_boq_item_names
    boq_items.update_all(contractor_name: full_name, updated_at: Time.current)
  end
end
