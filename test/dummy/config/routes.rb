Rails.application.routes.draw do
  mount SeederKit::Engine => "/seeder_kit"
end
