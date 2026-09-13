module BoqTestData
  def setup_boq
    @project = projects(:one)
    @plan = house_plans(:one)
    @admin = User.create!(name: "Admin", email: "admin@example.test", password: "test-password-123", role: :admin)
    @engineer = User.create!(name: "Engineer", email: "engineer@example.test", password: "test-password-123", role: :project_engineer)
    @master = MasterBoq.create!(house_plan: @plan)
    @category = @master.boq_categories.create!(name: "Structure", position: 1)
    @item = create_boq_item("CONCRETE")
  end

  def create_boq_item(code)
    @category.boq_items.create!(code: code, name: code, unit: "m3", material_quantity: 10,
      material_unit_price: 200, labor_unit_price: 100, contractor_name: "Team A")
  end

  def build_draw(amount: 400, item: @item, number: SecureRandom.hex(6))
    LaborDrawRequest.new(dv_number: number, project: @project, house_plan: @plan,
      contractor_name: "Team A", request_date: Date.current, user: @engineer,
      labor_draw_items_attributes: [ { boq_item: item, work_description: "Concrete work",
        quantity: 4, unit_price: 100, requested_amount: amount } ])
  end

  def create_po(quantity: 2, actual_price: 250)
    PurchaseOrder.create!(po_number: SecureRandom.hex(6), project: @project, house_plan: @plan,
      vendor_name: "Supplier", order_date: Date.current, status: :pending_pu,
      po_items_attributes: [ { boq_item: @item, item_name: "Concrete", quantity: quantity,
        material_unit_price: 200, actual_material_unit_price: actual_price, labor_unit_price: 100 } ])
  end
end
