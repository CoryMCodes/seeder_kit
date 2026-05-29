require "seeder_kit/version"
require "seeder_kit/engine"

module SeederKit
  def self.run(plan)
    ScenarioExecutor.new.call(plan)
  end

  def self.preview(plan)
    ScenarioPreview.new.call(plan)
  end

  def self.scenario(name, &block)
    scenario_registry.register(name, &block)
  end

  def self.scenarios
    scenario_registry.all
  end

  def self.run_scenario(name, **inputs)
    scenario_registry.run(name, **inputs)
  end

  def self.preview_scenario(name, **inputs)
    scenario_registry.preview(name, **inputs)
  end

  def self.scenario_registry
    @scenario_registry ||= ScenarioRegistry.new
  end
end
