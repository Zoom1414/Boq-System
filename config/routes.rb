Rails.application.routes.draw do
  devise_for :users
  root "master_boqs#show"
  get "dashboard", to: "dashboard#show"
  resources :purchase_orders, only: [ :new, :create, :index, :show ] do
    member do
      get :procure
      patch :complete
      patch :reject
    end
    collection do
      get :pending
      get :history
    end
  end
  resources :labor_draw_requests, only: [ :new, :create, :index, :show ] do
    member do
      patch :approve
      patch :reject
    end
  end
  get "approvals", to: "approvals#index"
  resources :contractors, only: [ :index, :show, :new, :create, :edit, :update ]

  # Developer Panel (role: dev)
  get "developer", to: "developer_panel#overview", as: :developer
  scope "developer", as: "developer", controller: "developer_panel" do
    get "users", action: :users
    post "users", action: :create_user
    patch "users/:id", action: :update_user, as: :user
    get "projects", action: :projects
    get "logins", action: :logins
    get "audit", action: :audit
    get "permissions", action: :permissions
    get "approvals", action: :approvals
    patch "approvals", action: :update_approvals
    get "cancellations", action: :cancellations
    patch "cancellations/:id", action: :cancel_draw, as: :cancel_draw
    get "notifications", action: :notifications
    patch "notifications", action: :update_notifications
    get "system", action: :system_control
    patch "system", action: :update_system
    get "export/:dataset", action: :export, as: :export
  end
  get "master_boq", to: "master_boqs#show", as: :master_boq
  post "house_plans/:house_plan_id/master_boq", to: "master_boqs#create", as: :create_master_boq
  resources :master_boqs, only: [] do
    member do
      get :export
      get :backup
      post :import
    end
    resources :boq_categories, only: [ :new, :create, :edit, :update, :destroy ]
    resources :boq_items, only: [ :new, :create, :edit, :update, :destroy ]
  end
  resources :projects do
    resources :house_plans
  end
end
