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
