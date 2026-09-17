module DeveloperPanelHelper
  THAI_SHORT_MONTHS = %w[ม.ค. ก.พ. มี.ค. เม.ย. พ.ค. มิ.ย. ก.ค. ส.ค. ก.ย. ต.ค. พ.ย. ธ.ค.].freeze

  def dp_time(time)
    return "—" unless time

    local = time.in_time_zone
    "#{local.day} #{THAI_SHORT_MONTHS[local.month - 1]} #{local.year + 543} #{local.strftime('%H:%M')}"
  end

  def dp_device(user_agent)
    ua = user_agent.to_s
    browser = ua[/Edg\//] ? "Edge" : ua[/Chrome\//] ? "Chrome" : ua[/Firefox\//] ? "Firefox" : ua[/Safari\//] ? "Safari" : "อื่น ๆ"
    os = ua[/Windows/] ? "Windows" : ua[/iPhone|iPad/] ? "iOS" : ua[/Android/] ? "Android" : ua[/Mac OS/] ? "macOS" : ua[/Linux/] ? "Linux" : ""
    ua.blank? ? "—" : [ browser, os.presence ].compact.join(" · ")
  end
end
