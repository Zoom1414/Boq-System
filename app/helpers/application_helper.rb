module ApplicationHelper
  PROJECT_STATUS_LABELS = {
    "planning" => "วางแผน", "active" => "กำลังก่อสร้าง",
    "completed" => "เสร็จสิ้น", "archived" => "เก็บถาวร"
  }.freeze
  ROLE_LABELS = { "dev" => "ผู้พัฒนา", "admin" => "ผู้ดูแลระบบ",
    "project_engineer" => "วิศวกรโครงการ", "user" => "ผู้ใช้งาน" }.freeze

  def project_status_badge(project)
    tag.span(PROJECT_STATUS_LABELS.fetch(project.status, project.status),
      class: "badge badge-#{project.status}")
  end

  def baht(amount)
    number_to_currency(amount || 0, unit: "฿", precision: 2)
  end

  def ui_icon(name, css: "size-5")
    paths = {
      building: "M3 21h18M5 21V7l7-4 7 4v14M9 10h.01M15 10h.01M9 14h.01M15 14h.01M10 21v-3h4v3",
      grid: "M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z",
      plus: "M12 5v14M5 12h14",
      arrow: "M5 12h14M13 6l6 6-6 6",
      pin: "M20 10c0 6-8 11-8 11S4 16 4 10a8 8 0 1 1 16 0ZM12 7a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
      home: "m3 10 9-7 9 7M5 9v12h14V9M9 21v-8h6v8",
      wallet: "M3 7h18v14H3zM3 7V4h15v3M16 12h5v5h-5z",
      check: "m5 12 4 4L19 6",
      logout: "M9 4H4v16h5M13 8l4 4-4 4M8 12h13",
      lock: "M5 10h14v11H5zM8 10V6a4 4 0 0 1 8 0v4",
      users: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75",
      search: "M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16M21 21l-4.3-4.3",
      bank: "M3 21h18M4 10h16M12 3l9 5H3zM6 10v8M10 10v8M14 10v8M18 10v8",
      code: "m16 18 6-6-6-6M8 6l-6 6 6 6",
      history: "M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5M12 7v5l3 2",
      shield: "M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10M9 12l2 2 4-4",
      bell: "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0",
      settings: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1",
      clipboard: "M9 3h6v4H9zM9 5H5v16h14V5h-4M9 12h6M9 16h4",
      power: "M12 2v10M18.4 6.6a9 9 0 1 1-12.8 0",
      x: "M18 6 6 18M6 6l12 12",
      download: "M12 3v12M7 10l5 5 5-5M5 21h14",
      refresh: "M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5",
      folder: "M3 6h6l2 2h10v12H3z",
      unlock: "M5 10h14v11H5zM8 10V6a4 4 0 0 1 7.7-1.5"
    }
    tag.svg(viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
      "stroke-width": 1.7, "stroke-linecap": "round", "stroke-linejoin": "round",
      class: css, "aria-hidden": true) { tag.path(d: paths.fetch(name.to_sym)) }
  end
end
