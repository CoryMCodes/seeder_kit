class CreateSeederKitScenarios < ActiveRecord::Migration[8.0]
  def change
    create_table :seeder_kit_scenarios do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
