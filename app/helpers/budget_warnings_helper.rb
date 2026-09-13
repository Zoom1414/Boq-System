module BudgetWarningsHelper
  # Include <div id="budget_warnings"></div> in the future PO/DV form.
  # Append this stream to the create/update response, even when warnings are empty.
  def budget_warning_stream(document)
    turbo_stream.update("budget_warnings", partial: "shared/budget_warnings",
      locals: { warnings: document.budget_warnings })
  end
end
