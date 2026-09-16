class BoqProgressSummary
  attr_reader :categories, :items

  def initialize(master)
    @groups = master ? master.boq_categories.includes(:boq_items).to_a : []
    @items = @groups.flat_map(&:boq_items)
    @categories = @groups.map do |category|
      { name: category.name, progress: percentage(category.boq_items), count: category.boq_items.size,
        completed: category.boq_items.count { |item| item.progress_percentage == 100 } }
    end
  end

  def overall
    percentage(items)
  end

  def completed_count
    items.count { |item| item.progress_percentage == 100 }
  end

  private

  def percentage(rows)
    return 0.to_d if rows.empty?
    budget = rows.sum { |item| item.material_total + item.labor_total }
    if budget.positive?
      (rows.sum { |item| (item.material_total + item.labor_total) * item.progress_percentage } / budget).round(1)
    else
      (rows.sum(&:progress_percentage) / rows.size).round(1)
    end
  end
end
