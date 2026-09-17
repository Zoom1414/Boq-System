# Construction progress based on materials actually used (approved PU) against BOQ quantity.
# Accepts one Master BOQ (a house plan) or several (a whole project).
class BoqProgressSummary
  attr_reader :categories, :items

  def self.percentage(rows)
    return 0.to_d if rows.empty?

    budget = rows.sum { |item| item.material_total + item.labor_total }
    if budget.positive?
      (rows.sum { |item| (item.material_total + item.labor_total) * item.capped_completion } / budget).round(1)
    else
      (rows.sum(&:capped_completion) / rows.size).round(1)
    end
  end

  def initialize(masters)
    groups = Array(masters).compact.flat_map { |master| master.boq_categories.includes(:boq_items).to_a }
    @items = groups.flat_map(&:boq_items)
    @categories = groups.group_by { |category| category.name.squish }.map do |name, same_name|
      rows = same_name.flat_map(&:boq_items)
      { name: name, progress: self.class.percentage(rows), count: rows.size, completed: rows.count(&:completed?) }
    end
  end

  def overall
    self.class.percentage(items)
  end

  def completed_count
    items.count(&:completed?)
  end
end
