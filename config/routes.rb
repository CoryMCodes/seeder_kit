SeederKit::Engine.routes.draw do
  root to: "scenarios#index"

  resources :scenarios, only: [ :index, :new, :create, :show ] do
    member do
      post :run # /scenarious/:id/run - to run s specific scenario
      get :export # /scenarious/:id/export -to preview/export seed script
    end
  end

  get "/models", to: "models#index"
end
