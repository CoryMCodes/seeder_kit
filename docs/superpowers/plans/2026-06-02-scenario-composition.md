# Scenario Composition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add shallow, deterministic composition of independent leaf scenarios before existing preview and execution paths.

**Architecture:** Extend `ScenarioDefinition` with ordered `include_scenario` declarations and add a focused `ScenarioComposer` service. The registry asks the composer for one merged structured plan before calling existing preview or execution services, preserving current validation and transaction behavior.

**Tech Stack:** Ruby 3.4.9, Rails 8.0.2 engine, Active Record, Minitest, RuboCop Rails Omakase

---

## File Structure

- Create `app/services/seeder_kit/scenario_composer.rb`
  - Resolve shallow child includes into one normalized `{ entities: [...] }` plan hash.
  - Reject nested composition, missing parent mappings, and external child refs.
  - Stay side-effect free.
- Create `test/services/scenario_composer_test.rb`
  - Cover focused composer behavior and error boundaries.
- Create `test/services/scenario_composition_integration_test.rb`
  - Prove registry preview and run use the composer while retaining validation and transaction behavior.
- Modify `app/services/seeder_kit/scenario_definition.rb`
  - Add the ordered include DSL and reject mixed leaf/composed definitions.
- Modify `app/services/seeder_kit/scenario_registry.rb`
  - Compose named scenarios before preview or execution.
- Modify `test/services/scenario_registry_test.rb`
  - Cover DSL declaration storage and mixed-definition errors.
- Modify `docs/architecture-plan.md`
  - Record registry, typed inputs, preview, and shallow composition as implemented engine slices.

Do not modify the standalone Vite web tool. Composition is a Rails-engine contract and does not change the public `schema.rb -> seeds.rb` utility.

## Task 0: Restore The Local Ruby Bundle

The baseline Rails checks currently stop before test boot because Ruby `3.4.9` is missing locally installed gems: `cgi-0.5.1`, `minitest-5.27.0`, and `unicode-emoji-4.2.0`.

- [ ] **Step 1: Install the locked bundle**

Run:

```bash
mise exec -- bundle install
```

Expected: Bundler installs the missing locked gems and finishes with `Bundle complete!`.

- [ ] **Step 2: Confirm the test harness boots before feature edits**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_registry_test.rb
```

Expected: PASS. If dependency installation is unavailable, record the environment blocker before continuing; do not treat a Bundler boot failure as a feature regression.

## Task 1: Add The Ordered Composition DSL

**Files:**
- Modify: `app/services/seeder_kit/scenario_definition.rb`
- Modify: `test/services/scenario_registry_test.rb`

- [ ] **Step 1: Add failing DSL tests**

Append these tests inside `SeederKit::ScenarioRegistryTest`:

```ruby
test "stores ordered child scenario includes" do
  definition = SeederKit.scenario "Demo content" do
    include_scenario "Users with posts", user_count: :user_count
    include_scenario "Archived article", title: "Old news"
  end

  first_include, second_include = definition.scenario_includes

  assert definition.composed?
  assert_equal "Users with posts", first_include.name
  assert_equal({ user_count: :user_count }, first_include.input_bindings)
  assert_equal "Archived article", second_include.name
  assert_equal({ title: "Old news" }, second_include.input_bindings)
end

test "rejects adding includes after a plan" do
  error = assert_raises(ScenarioDefinition::MixedDefinitionError) do
    SeederKit.scenario "Mixed leaf first" do
      plan(entities: [])
      include_scenario "Users"
    end
  end

  assert_equal "Scenario Mixed leaf first cannot define both plan and include_scenario", error.message
end

test "rejects adding a plan after includes" do
  error = assert_raises(ScenarioDefinition::MixedDefinitionError) do
    SeederKit.scenario "Mixed composition first" do
      include_scenario "Users"
      plan(entities: [])
    end
  end

  assert_equal "Scenario Mixed composition first cannot define both plan and include_scenario", error.message
end
```

- [ ] **Step 2: Run the DSL tests to verify they fail**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_registry_test.rb
```

Expected: FAIL because `include_scenario`, `scenario_includes`, `composed?`, and `MixedDefinitionError` do not exist yet.

- [ ] **Step 3: Add the minimal DSL implementation**

Update `app/services/seeder_kit/scenario_definition.rb` with these additions. Keep the existing input-resolution methods unchanged.

Add the include value object and mixed-definition error after `InputDefinition`:

```ruby
IncludeDefinition = Data.define(:name, :input_bindings)

class InputError < ArgumentError; end
class MixedDefinitionError < ArgumentError; end
```

Replace the reader and initializer with:

```ruby
attr_reader :name, :input_definitions, :scenario_includes

def initialize(name)
  @name = name.to_s
  @description = nil
  @plan = nil
  @plan_defined = false
  @input_definitions = {}
  @scenario_includes = []
end
```

Replace `plan` and add `include_scenario` and `composed?`:

```ruby
def plan(value = UNSET, &block)
  if block && !value.equal?(UNSET)
    raise ArgumentError, "Provide a static plan or a plan block, not both"
  end

  if (!value.equal?(UNSET) || block) && composed?
    raise MixedDefinitionError, mixed_definition_message
  end

  unless value.equal?(UNSET) && !block
    @plan = block || value
    @plan_defined = true
  end

  @plan
end

def include_scenario(name, **input_bindings)
  raise MixedDefinitionError, mixed_definition_message if @plan_defined

  scenario_includes << IncludeDefinition.new(
    name: name.to_s,
    input_bindings: input_bindings.dup
  )
end

def composed?
  scenario_includes.any?
end
```

Add this private helper before `normalize_overrides`:

```ruby
def mixed_definition_message
  "Scenario #{name} cannot define both plan and include_scenario"
end
```

- [ ] **Step 4: Run the DSL tests to verify they pass**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_registry_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit the DSL**

```bash
git add app/services/seeder_kit/scenario_definition.rb test/services/scenario_registry_test.rb
git commit -m "Add scenario composition DSL"
```

## Task 2: Add The Side-Effect-Free Composer

**Files:**
- Create: `app/services/seeder_kit/scenario_composer.rb`
- Create: `test/services/scenario_composer_test.rb`

- [ ] **Step 1: Write focused failing composer tests**

Create `test/services/scenario_composer_test.rb`:

```ruby
require "test_helper"

module SeederKit
  class ScenarioComposerTest < ActiveSupport::TestCase
    setup do
      @registry = ScenarioRegistry.new
      @composer = ScenarioComposer.new(registry: @registry)
    end

    test "merges leaf entities in include order with mappings literals and child defaults" do
      @registry.register "Users" do
        input :user_count, type: :integer, default: 1

        plan do |inputs|
          {
            entities: [
              { ref: "users", model: "User", count: inputs.fetch(:user_count) }
            ]
          }
        end
      end

      @registry.register "Archived article" do
        input :title, type: :string
        input :status, type: :string, default: "archived"

        plan do |inputs|
          {
            entities: [
              {
                ref: "archived_post",
                model: "Post",
                attributes: {
                  title: inputs.fetch(:title),
                  status: inputs.fetch(:status)
                }
              }
            ]
          }
        end
      end

      definition = @registry.register "Demo content" do
        input :demo_user_count, type: :integer, default: 2

        include_scenario "Users", user_count: :demo_user_count
        include_scenario "Archived article", title: "Old news"
      end

      plan = @composer.call(definition, demo_user_count: 4)

      assert_equal [ "users", "archived_post" ], plan.fetch(:entities).map { |entity| entity.fetch(:ref) }
      assert_equal 4, plan.fetch(:entities).fetch(0).fetch(:count)
      assert_equal(
        { "title" => "Old news", "status" => "archived" },
        plan.fetch(:entities).fetch(1).fetch(:attributes)
      )
    end

    test "composition does not write records" do
      definition = @registry.register "No writes" do
        include_scenario "User leaf"
      end

      @registry.register "User leaf" do
        plan(
          entities: [
            {
              ref: "user",
              model: "User",
              attributes: { email: "compose-only@example.com" }
            }
          ]
        )
      end

      assert_no_difference -> { User.count } do
        @composer.call(definition)
      end
    end

    test "rejects a missing parent input mapping" do
      @registry.register "Users" do
        input :user_count, type: :integer
        plan(entities: [])
      end

      definition = @registry.register "Broken mapping" do
        include_scenario "Users", user_count: :missing_count
      end

      error = assert_raises(ScenarioComposer::MissingParentInputError) do
        @composer.call(definition)
      end

      assert_equal "Unknown parent input for scenario Broken mapping: missing_count", error.message
    end

    test "reuses child required input errors" do
      @registry.register "Users" do
        input :user_count, type: :integer
        plan(entities: [])
      end

      definition = @registry.register "Missing child input" do
        include_scenario "Users"
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        @composer.call(definition)
      end

      assert_equal "Missing required input for scenario Users: user_count", error.message
    end

    test "reuses child invalid input errors" do
      @registry.register "Users" do
        input :user_count, type: :integer
        plan(entities: [])
      end

      definition = @registry.register "Invalid child input" do
        include_scenario "Users", user_count: "four"
      end

      error = assert_raises(ScenarioDefinition::InputError) do
        @composer.call(definition)
      end

      assert_equal "Invalid input type for scenario Users: user_count must be integer", error.message
    end

    test "reuses the registry unknown scenario error" do
      definition = @registry.register "Missing child parent" do
        include_scenario "Missing child"
      end

      error = assert_raises(ScenarioRegistry::UnknownScenarioError) do
        @composer.call(definition)
      end

      assert_equal "Unknown SeederKit scenario: Missing child", error.message
    end

    test "rejects nested composition" do
      @registry.register "Leaf" do
        plan(entities: [])
      end

      @registry.register "Nested child" do
        include_scenario "Leaf"
      end

      definition = @registry.register "Nested parent" do
        include_scenario "Nested child"
      end

      error = assert_raises(ScenarioComposer::NestedCompositionError) do
        @composer.call(definition)
      end

      assert_equal "Scenario Nested parent cannot include composed scenario Nested child", error.message
    end

    test "rejects cross child refs" do
      @registry.register "Users" do
        plan(
          entities: [
            { ref: "user", model: "User" }
          ]
        )
      end

      @registry.register "Posts" do
        plan(
          entities: [
            { ref: "post", model: "Post", belongs_to: { user: "user" } }
          ]
        )
      end

      definition = @registry.register "Cross child refs" do
        include_scenario "Users"
        include_scenario "Posts"
      end

      error = assert_raises(ScenarioComposer::CrossChildReferenceError) do
        @composer.call(definition)
      end

      assert_equal "Scenario Cross child refs includes Posts with an external ref: user", error.message
    end
  end
end
```

- [ ] **Step 2: Run the composer tests to verify they fail**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_composer_test.rb
```

Expected: FAIL because `SeederKit::ScenarioComposer` does not exist.

- [ ] **Step 3: Implement the composer**

Create `app/services/seeder_kit/scenario_composer.rb`:

```ruby
module SeederKit
  class ScenarioComposer
    class NestedCompositionError < ArgumentError; end
    class MissingParentInputError < ArgumentError; end
    class CrossChildReferenceError < ArgumentError; end

    def initialize(registry:)
      @registry = registry
    end

    def call(definition, overrides = {})
      return definition.build_plan(overrides) unless definition.composed?

      parent_inputs = definition.resolve_inputs(overrides)

      {
        entities: definition.scenario_includes.flat_map do |scenario_include|
          entities_for(definition, scenario_include, parent_inputs)
        end
      }
    end

    private

    attr_reader :registry

    def entities_for(parent, scenario_include, parent_inputs)
      child = registry.fetch(scenario_include.name)

      if child.composed?
        raise NestedCompositionError,
              "Scenario #{parent.name} cannot include composed scenario #{child.name}"
      end

      child_plan = ScenarioPlan.build(
        child.build_plan(resolve_child_overrides(parent, scenario_include, parent_inputs))
      )

      validate_internal_refs!(parent, child, child_plan)

      child_plan.entities.map { |entity| entity_hash(entity) }
    end

    def resolve_child_overrides(parent, scenario_include, parent_inputs)
      scenario_include.input_bindings.transform_values do |binding|
        next binding unless binding.is_a?(Symbol)

        unless parent_inputs.key?(binding)
          raise MissingParentInputError,
                "Unknown parent input for scenario #{parent.name}: #{binding}"
        end

        parent_inputs.fetch(binding)
      end
    end

    def validate_internal_refs!(parent, child, child_plan)
      child_refs = child_plan.entities.map(&:ref)

      child_plan.entities.each do |entity|
        entity.belongs_to.each_value do |target_ref|
          next if child_refs.include?(target_ref.to_s)

          raise CrossChildReferenceError,
                "Scenario #{parent.name} includes #{child.name} with an external ref: #{target_ref}"
        end
      end
    end

    def entity_hash(entity)
      {
        ref: entity.ref,
        model: entity.model,
        count: entity.count,
        attributes: entity.attributes.dup,
        belongs_to: entity.belongs_to.dup
      }
    end
  end
end
```

- [ ] **Step 4: Run the composer tests to verify they pass**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_composer_test.rb
```

Expected: PASS.

- [ ] **Step 5: Run DSL and composer tests together**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_registry_test.rb test/services/scenario_composer_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit the composer**

```bash
git add app/services/seeder_kit/scenario_composer.rb test/services/scenario_composer_test.rb
git commit -m "Add deterministic scenario composer"
```

## Task 3: Route Named Preview And Execution Through Composition

**Files:**
- Modify: `app/services/seeder_kit/scenario_registry.rb`
- Create: `test/services/scenario_composition_integration_test.rb`

- [ ] **Step 1: Add failing registry integration tests**

Create `test/services/scenario_composition_integration_test.rb`:

```ruby
require "test_helper"

module SeederKit
  class ScenarioCompositionIntegrationTest < ActiveSupport::TestCase
    setup do
      SeederKit.scenario_registry.clear
    end

    test "preview_scenario composes leaf plans without writes" do
      register_user_leaf("First user", ref: "first_user", email: "first@example.com")
      register_user_leaf("Second user", ref: "second_user", email: "second@example.com")

      SeederKit.scenario "Preview users" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      assert_no_difference -> { User.count } do
        result = SeederKit.preview_scenario("Preview users")

        assert_equal 2, result.total_records
        assert_equal [ "first_user", "second_user" ], result.entities.map(&:ref)
      end
    end

    test "run_scenario executes one composed plan" do
      register_user_leaf("First user", ref: "first_user", email: "first@example.com")
      register_user_leaf("Second user", ref: "second_user", email: "second@example.com")

      SeederKit.scenario "Run users" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      assert_difference -> { User.count }, 2 do
        result = SeederKit.run_scenario("Run users")

        assert_equal [ "first_user", "second_user" ], result.records_by_ref.keys
      end
    end

    test "preview rejects duplicate refs after composition" do
      register_user_leaf("First user", ref: "user", email: "first@example.com")
      register_user_leaf("Second user", ref: "user", email: "second@example.com")

      SeederKit.scenario "Duplicate preview" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      error = assert_raises(BasicScenarioValidator::ValidationError) do
        SeederKit.preview_scenario("Duplicate preview")
      end

      assert error.errors.any? { |validation_error| validation_error[:code] == "duplicate_ref" }
    end

    test "run rejects duplicate refs before writes" do
      register_user_leaf("First user", ref: "user", email: "first@example.com")
      register_user_leaf("Second user", ref: "user", email: "second@example.com")

      SeederKit.scenario "Duplicate run" do
        include_scenario "First user"
        include_scenario "Second user"
      end

      assert_no_difference -> { User.count } do
        error = assert_raises(BasicScenarioValidator::ValidationError) do
          SeederKit.run_scenario("Duplicate run")
        end

        assert error.errors.any? { |validation_error| validation_error[:code] == "duplicate_ref" }
      end
    end

    test "composed execution rolls back earlier children when a later child fails" do
      register_user_leaf("Valid user", ref: "valid_user", email: "valid@example.com")

      SeederKit.scenario "Invalid user" do
        plan(
          entities: [
            { ref: "invalid_user", model: "User", attributes: { name: "Missing email" } }
          ]
        )
      end

      SeederKit.scenario "Rollback users" do
        include_scenario "Valid user"
        include_scenario "Invalid user"
      end

      assert_no_difference -> { User.count } do
        assert_raises(ActiveRecord::RecordInvalid) do
          SeederKit.run_scenario("Rollback users")
        end
      end
    end

    private

    def register_user_leaf(name, ref:, email:)
      SeederKit.scenario name do
        plan(
          entities: [
            { ref: ref, model: "User", attributes: { email: email } }
          ]
        )
      end
    end
  end
end
```

- [ ] **Step 2: Run the integration tests to verify they fail**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_composition_integration_test.rb
```

Expected: FAIL because `ScenarioRegistry#run` and `#preview` still call `build_plan` directly on the composed parent definition, which has no leaf plan.

- [ ] **Step 3: Wire the registry through the composer**

Replace the named execution methods in `app/services/seeder_kit/scenario_registry.rb`:

```ruby
def run(name, **inputs)
  SeederKit.run(build_plan(name, inputs))
end

def preview(name, **inputs)
  SeederKit.preview(build_plan(name, inputs))
end

def clear
  definitions_by_name.clear
end

private

attr_reader :definitions_by_name

def build_plan(name, inputs)
  ScenarioComposer.new(registry: self).call(fetch(name), inputs)
end
```

- [ ] **Step 4: Run the integration tests to verify they pass**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_composition_integration_test.rb
```

Expected: PASS.

- [ ] **Step 5: Run all scenario service tests**

Run:

```bash
mise exec -- bin/rails test test/services/scenario_plan_test.rb test/services/basic_scenario_validator_test.rb test/services/scenario_executor_test.rb test/services/scenario_registry_test.rb test/services/scenario_preview_test.rb test/services/scenario_composer_test.rb test/services/scenario_composition_integration_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit registry integration**

```bash
git add app/services/seeder_kit/scenario_registry.rb test/services/scenario_composition_integration_test.rb
git commit -m "Compose scenarios before preview and execution"
```

## Task 4: Update The Architecture Tracker

**Files:**
- Modify: `docs/architecture-plan.md`

- [ ] **Step 1: Update the architecture date and scenario flow**

Change the document date to:

```markdown
Last updated: 2026-06-02
```

Replace the scenario flow inside `Current System Map` with:

```txt
  ScenarioDefinition -> ScenarioRegistry -> ScenarioComposer
    named scenarios -> typed inputs -> shallow independent composition

  ScenarioPlan -> BasicScenarioValidator -> ScenarioPreview / ScenarioExecutor
    one structured plan -> basic validation -> preview or transaction-wrapped create!
```

- [ ] **Step 2: Add the implemented registry, preview, and composition slice**

Insert this section after `Phase 5 - Execution Engine` and before `Phase 6 - CLI Surface`:

```markdown
## Implemented Vertical Slice - Registry, Preview, and Shallow Composition

Goal: Build reusable named scenario recipes on top of the structured scenario contract.

Checkpoints:

- [x] Add `SeederKit::ScenarioRegistry`.
- [x] Add typed parameterized scenario inputs.
- [x] Add side-effect-free `SeederKit::ScenarioPreview`.
- [x] Add shallow `SeederKit::ScenarioComposer`.
- [x] Merge leaf scenario plans deterministically in include order.
- [x] Support parent-input mappings and literal child input values.
- [x] Reject duplicate refs through existing plan validation.
- [x] Reject nested composition and cross-child refs for the first composition slice.

Deferred composition capabilities:

- nested scenario composition
- cross-child entity references
- inline parent entities in composed scenarios
- ref renaming or namespacing

Definition of done:

- Reusable leaf scenarios can be combined into one inspectable structured plan.
- Preview remains side-effect free.
- Execution still validates once and runs in one transaction.
```

- [ ] **Step 3: Replace the stale current-next-step section**

Replace the existing `Current Next Step` content with:

```markdown
## Current Next Step

Choose the next product slice after shallow scenario composition is merged.

Candidate directions:

- Add a Rails-native CLI for listing, previewing, and running registered scenarios.
- Connect the Rails UI prototype to registered scenarios, typed inputs, preview, and run.
- Design recursive composition and explicit cross-child ref contracts if real scenarios require them.
- Add deterministic attribute resolution when required-value boilerplate becomes the limiting problem.
```

- [ ] **Step 4: Review the documentation diff**

Run:

```bash
git diff -- docs/architecture-plan.md
```

Expected: the tracker reflects the implemented composition slice and no longer says attribute resolution is automatically next.

- [ ] **Step 5: Commit the tracker update**

```bash
git add docs/architecture-plan.md
git commit -m "Update architecture tracker for scenario composition"
```

## Task 5: Verify The Completed Slice

**Files:**
- Verify only

- [ ] **Step 1: Run the full Rails test suite**

Run:

```bash
mise exec -- bin/rails test
```

Expected: PASS.

- [ ] **Step 2: Run RuboCop**

Run:

```bash
mise exec -- bin/rubocop
```

Expected: PASS with no offenses.

- [ ] **Step 3: Confirm unrelated worktree changes remain untouched**

Run:

```bash
git status --short --branch
```

Expected: the pre-existing `.github/workflows/ci.yml` edit and local BMad files may remain. Do not stage or revert them as part of this slice.

- [ ] **Step 4: Inspect the composition commit series**

Run:

```bash
git log --oneline --decorate -n 6
```

Expected: the history contains the design spec followed by the focused DSL, composer, registry-integration, and architecture-tracker commits.
