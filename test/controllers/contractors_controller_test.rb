require "test_helper"

class ContractorsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { setup_boq }

  test "admin creates, edits and searches contractors" do
    sign_in @admin
    get new_contractor_path
    assert_response :success
    assert_difference "Contractor.count", 1 do
      post contractors_path, params: { contractor: { first_name: "สมศักดิ์", last_name: "ช่างไม้", trade: "ช่างไม้",
        bank_name: Contractor::BANKS.first, bank_account_number: "222-3-33333-3", bank_account_name: "สมศักดิ์" } }
    end
    contractor = Contractor.find_by_name("สมศักดิ์ ช่างไม้")
    assert_redirected_to contractor_path(contractor)
    patch contractor_path(contractor), params: { contractor: { phone: "0812345678" } }
    assert_equal "0812345678", contractor.reload.phone
    get contractors_path, params: { q: "ช่างไม้" }
    assert_response :success
    assert_select ".ct-person", text: /สมศักดิ์/
    assert_select ".ct-person", text: /Team A/, count: 0
    get contractor_path(@contractor)
    assert_select ".ct-bank-number", text: "123-4-56789-0"
  end

  test "duplicate bank account is rejected with a clear message" do
    sign_in @admin
    assert_no_difference "Contractor.count" do
      post contractors_path, params: { contractor: { first_name: "Copy", bank_name: Contractor::BANKS.first,
        bank_account_number: "1234567890", bank_account_name: "Copy" } }
    end
    assert_response :unprocessable_entity
    assert_select ".alert", text: /Team A/
  end

  test "non-admins can view with masked accounts but cannot edit" do
    sign_in @engineer
    get contractors_path
    assert_response :success
    get contractor_path(@contractor)
    assert_response :success
    assert_select ".ct-bank-number", text: /7890/
    assert_select ".ct-bank-number", text: "123-4-56789-0", count: 0
    get new_contractor_path
    assert_response :forbidden
    patch contractor_path(@contractor), params: { contractor: { bank_account_number: "9999999999" } }
    assert_response :forbidden
    assert_equal "1234567890", @contractor.reload.bank_account_number
  end

  test "payment history lists approved installments" do
    draw = build_draw.tap(&:save!)
    ApproveLaborDrawService.new(draw, actor: @admin).call
    sign_in @engineer
    get contractor_path(@contractor)
    assert_select ".ct-installment", text: /งวด 1/
    assert_select "a.document-link", text: draw.dv_number
  end

  test "DV form blocks contractors without a bank account" do
    nobank = Contractor.create!(first_name: "No Bank")
    create_boq_item("ROOF").update!(contractor: nobank)
    sign_in @engineer
    get new_labor_draw_request_path, params: { project_id: @project.id, house_plan_id: @plan.id, contractor_id: nobank.id }
    assert_response :success
    assert_select ".ct-payee.is-missing"
    assert_select ".labor-form", count: 0
  end
end
