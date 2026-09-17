require "test_helper"

class ContractorTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "normalizes names and bank account digits" do
    contractor = Contractor.create!(first_name: "  สมชาย ", last_name: "ใจดี", bank_name: Contractor::BANKS.second,
      bank_account_number: "987 6 54321-0", bank_account_name: "สมชาย ใจดี")
    assert_equal "สมชาย ใจดี", contractor.full_name
    assert_equal "9876543210", contractor.bank_account_number
    assert contractor.bank_ready?
  end

  test "a bank account cannot belong to two contractors" do
    duplicate = Contractor.new(first_name: "Other", bank_name: Contractor::BANKS.last,
      bank_account_number: "1234567890", bank_account_name: "Other")
    assert_not duplicate.valid?
    assert_match(/Team A/, duplicate.errors[:bank_account_number].first)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "full names are unique and bank details must be complete" do
    assert_not Contractor.new(first_name: "team a").valid?
    partial = Contractor.new(first_name: "Partial", bank_account_number: "1112223334")
    assert_not partial.valid?
    assert_includes partial.errors[:base].join, "ครบ"
  end

  test "search matches name, trade and account digits" do
    Contractor.create!(first_name: "Electric", trade: "ช่างไฟฟ้า")
    assert_equal [ "Team A" ], Contractor.search("567-89").pluck(:full_name)
    assert_equal [ "Electric" ], Contractor.search("ไฟฟ้า").pluck(:full_name)
    assert_equal 2, Contractor.search("").count
  end

  test "one contractor can take many BOQ items and renames follow" do
    other = create_boq_item("WALL")
    assert_equal @contractor, other.contractor
    assert_equal 2, @contractor.boq_items.count
    @contractor.update!(first_name: "Team Alpha")
    assert_equal [ "Team Alpha" ], @contractor.boq_items.pluck(:contractor_name).uniq
  end

  test "DV snapshots the payee account and requires bank details" do
    draw = build_draw.tap(&:save!)
    assert_equal @contractor, draw.contractor
    assert_equal "1234567890", draw.payee_bank_account_number
    @contractor.update!(bank_account_number: "5555555555")
    assert_equal "1234567890", draw.reload.payee_bank_account_number

    nobank = Contractor.create!(first_name: "No Bank")
    item = create_boq_item("ROOF")
    item.update!(contractor: nobank)
    blocked = build_draw(item: item)
    blocked.contractor_name = "No Bank"
    assert_not blocked.valid?
    assert_match(/บัญชี/, blocked.errors.full_messages.join)
  end
end
