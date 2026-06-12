SeederKit::Engine.routes.draw do
  root to: "seed_generators#new"

  post "/generate", to: "seed_generators#create", as: :generate

  get "/models", to: "models#index"
  get "/domain_graph", to: "domain_graphs#show"
end
