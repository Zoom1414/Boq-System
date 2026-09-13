class BudgetCheckService
  WARNING = "Warning: This request exceeds the Master BOQ budget limit. Require Admin approval override.".freeze

  def initialize(document, boq_items: nil)
    @document = document
    @boq_items = boq_items
  end

  def warnings
    @document.line_items.reject(&:marked_for_destruction?).group_by(&:boq_item_id).filter_map do |id, rows|
      next unless id
      item = @boq_items ? @boq_items.fetch(id) : BoqItem.find_by(id: id)
      next unless item

      labor = rows.sum { |row| row.is_a?(PoItem) ? row.labor_amount : row.requested_amount.to_d }
      material = rows.sum { |row| row.is_a?(PoItem) ? row.quantity.to_d : 0.to_d }
      if (labor.positive? && labor > item.labor_remaining_amount) ||
          (material.positive? && material > item.material_remaining_qty)
        { boq_item_id: id, code: item.code, message: WARNING,
          labor_shortfall: labor.positive? ? [ labor - item.labor_remaining_amount, 0.to_d ].max : 0.to_d,
          material_shortfall: material.positive? ? [ material - item.material_remaining_qty, 0.to_d ].max : 0.to_d }
      end
    end
  end
end
