require "csv"

class ImportBoqService
  class InvalidFile < StandardError; end
  ITEM_FIELDS = %w[code name unit material_quantity material_unit_price labor_unit_price contractor_name note].freeze
  HEADERS = [ "category", *ITEM_FIELDS ].freeze

  def initialize(master, file)
    @master, @file = master, file
  end

  def call
    raise InvalidFile, "เลือกไฟล์ CSV ขนาดไม่เกิน 2 MB" unless @file && @file.size <= 2.megabytes
    content = @file.read.force_encoding("UTF-8").delete_prefix("\uFEFF")
    raise InvalidFile, "ไฟล์ต้องเป็น UTF-8" unless content.valid_encoding?
    rows = CSV.parse(content, headers: true)
    raise InvalidFile, "ใช้หัวคอลัมน์จากไฟล์ Export" unless rows.headers == HEADERS
    raise InvalidFile, "รองรับ 1–500 รายการต่อไฟล์" unless rows.size.between?(1, 500)

    @master.with_lock do
      rows.each do |row|
        raise InvalidFile, "กรุณาระบุ category" if row["category"].blank?
        category = @master.boq_categories.find_by(name: row["category"]) ||
          @master.boq_categories.create!(name: row["category"], position: (@master.boq_categories.maximum(:position) || 0) + 1)
        category.boq_items.create!(row.to_h.slice(*ITEM_FIELDS))
      end
    end
  rescue CSV::MalformedCSVError => error
    raise InvalidFile, error.message
  end
end
