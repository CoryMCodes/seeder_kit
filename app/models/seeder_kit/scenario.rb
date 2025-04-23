module SeederKit
  class Scenario < ApplicationRecord
    validates :name, presence: true
  end
end
