class DocumentSequence < ApplicationRecord
  def self.next_number(prefix)
    key = "#{prefix}-#{Date.current.strftime('%y%m')}"
    sequence = create_or_find_by!(name: key)
    sequence.with_lock do
      sequence.increment!(:value)
      "#{key}-#{sequence.value.to_s.rjust(3, '0')}"
    end
  end
end
