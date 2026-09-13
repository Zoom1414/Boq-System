require "test_helper"

class ImportBoqServiceTest < ActiveSupport::TestCase
  setup { setup_boq }

  test "import creates new categories and calculates budgets without deductions" do
    file = StringIO.new(CSV.generate do |csv|
      csv << ImportBoqService::HEADERS
      csv << [ "Finish", "FIN-01", "Paint", "m2", "2.5", "100", "50", "Team A", "Imported" ]
    end)
    ImportBoqService.new(@master, file).call
    item = @master.boq_items.find_by!(code: "FIN-01")
    assert_equal 250, item.material_total
    assert_equal 125, item.labor_total
    assert_equal 0, item.labor_paid_amount
  end

  test "one invalid row rolls back the entire import including rollups" do
    file = StringIO.new(CSV.generate do |csv|
      csv << ImportBoqService::HEADERS
      csv << [ "New", "OK", "Paint", "m2", "2", "100", "50", "Team A", "" ]
      csv << [ "New", "BAD", "Paint", "m2", "-1", "100", "50", "Team A", "" ]
    end)
    original = @master.reload.total_material_budget
    assert_no_difference [ "BoqCategory.count", "BoqItem.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { ImportBoqService.new(@master, file).call }
    end
    assert_equal original, @master.reload.total_material_budget
  end

  test "missing files and unexpected headers are rejected" do
    assert_raises(ImportBoqService::InvalidFile) { ImportBoqService.new(@master, nil).call }
    assert_raises(ImportBoqService::InvalidFile) { ImportBoqService.new(@master, StringIO.new("name,price\nA,10")).call }
  end
end
