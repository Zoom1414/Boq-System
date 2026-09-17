module ContractorsHelper
  def bank_account_display(number, reveal: policy(Contractor).view_bank_account?)
    return "—" if number.blank?
    return format_bank_account(number) if reveal

    "••• ••• #{number.last(4)}"
  end

  def format_bank_account(number)
    number.length == 10 ? "#{number[0, 3]}-#{number[3]}-#{number[4, 5]}-#{number[9]}" : number
  end

  def contractor_initials(contractor)
    contractor.full_name.to_s.first
  end
end
