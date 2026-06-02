# Scenario Composition Design

Date: 2026-06-02

## Purpose

Add a small, deterministic scenario-composition layer so larger product states
can reuse existing leaf scenarios. This moves SeederKit closer to requests such
as "make users with posts and add archived content" without adding CLI, UI, AI,
or attribute resolution work.

## Scope

This slice adds shallow, independent composition:

- A composed scenario includes leaf scenarios in declaration order.
- Each included child is self-contained.
- Child plans are concatenated into one structured plan before preview or
  execution.
- Duplicate entity refs fail clearly during existing plan validation.
- The composer is side-effect free.

This slice deliberately does not add:

- nested scenario composition
- cross-child entity references
- inline parent entities in a composed scenario
- ref renaming or namespacing
- CLI commands
- UI changes
- AI planning
- attribute resolution
- persistent scenario runs

## Public DSL

A leaf scenario continues to define a plan:

```ruby
SeederKit.scenario "Users with posts" do
  input :user_count, type: :integer, default: 5
  input :posts_per_user, type: :integer, default: 3

  plan do |inputs|
    {
      entities: [
        # Existing leaf scenario entities.
      ]
    }
  end
end
```

A composed scenario defines ordered child includes:

```ruby
SeederKit.scenario "Demo content" do
  input :user_count, type: :integer, default: 5

  include_scenario "Users with posts",
    user_count: :user_count,
    posts_per_user: 3

  include_scenario "Archived article",
    title: "Old news"
end
```

A scenario definition may use `plan` or `include_scenario`, but not both.
Included scenarios must be leaf scenarios.

## Components

### `SeederKit::ScenarioDefinition`

`ScenarioDefinition` retains responsibility for the scenario DSL and typed
input resolution. It stores ordered include declarations alongside existing
input definitions and plan declarations.

Each include declaration contains:

- the child scenario name
- child input bindings in declaration order

`ScenarioDefinition` rejects mixed definitions that use both `plan` and
`include_scenario`.

### `SeederKit::ScenarioComposer`

`ScenarioComposer` is a focused, side-effect-free orchestration service. It
accepts a registry, a root scenario definition, and caller-provided input
overrides. It returns one structured plan hash:

```ruby
{
  entities: [
    # Child entities concatenated in include order.
  ]
}
```

The composer does not:

- validate models or attributes
- write records
- reorder entities
- alter refs
- allow cross-child references

### `SeederKit::ScenarioRegistry`

`ScenarioRegistry#run` and `ScenarioRegistry#preview` delegate plan building to
`ScenarioComposer`. The resulting single plan continues through the existing
public paths:

```txt
run_scenario
-> ScenarioRegistry
-> ScenarioComposer
-> SeederKit.run
-> ScenarioExecutor

preview_scenario
-> ScenarioRegistry
-> ScenarioComposer
-> SeederKit.preview
-> ScenarioPreview
```

Existing direct `SeederKit.run(plan)` and `SeederKit.preview(plan)` behavior is
unchanged.

## Resolution Rules

When building a composed scenario:

1. Resolve and validate the parent scenario inputs with the existing typed
   input behavior.
2. Process child includes in declaration order.
3. Fetch each child scenario from the same registry.
4. Reject the child when it includes scenarios of its own.
5. Resolve child overrides from the include declaration:
   - A symbol value such as `:user_count` reads that key from the resolved
     parent inputs.
   - A non-symbol value such as `3` or `"Old news"` passes through literally.
6. Build the leaf child plan through its existing `build_plan`, reusing child
   defaults, required-input checks, unknown-input checks, and type checks.
7. Reject any child entity `belongs_to` target that is not declared by another
   entity in the same child plan. This prevents accidental cross-child
   references while allowing normal relationships inside a leaf scenario.
8. Concatenate each child's `entities` array in include order.
9. Return one `{ entities: merged_entities }` hash.

If a symbol mapping refers to an undeclared parent input, composition fails
clearly before child plan building.

Leaf scenarios continue to build their plans exactly as they do today.

## Validation And Errors

Composition adds focused errors:

- `MixedDefinitionError`: a scenario defines both a plan and child includes.
- `NestedCompositionError`: an included child also contains child includes.
- `MissingParentInputError`: a symbol mapping refers to an undeclared parent
  input.
- `CrossChildReferenceError`: a child plan contains a `belongs_to` target that
  is not declared inside that same child plan.

Existing errors remain authoritative where they already fit:

- `ScenarioRegistry::UnknownScenarioError`: an included child is not
  registered.
- `ScenarioDefinition::InputError`: child input overrides are unknown, missing,
  or invalid.
- `BasicScenarioValidator::ValidationError` with `duplicate_ref`: merged child
  plans contain colliding refs.

Duplicate refs are intentionally not renamed or namespaced. The existing
validator reports them during preview or execution validation, keeping the
composer narrowly focused on deterministic plan construction.

## Transaction Behavior

The composer produces one structured plan hash and does not execute child
scenarios individually. `ScenarioExecutor` receives the merged plan and runs it
through its existing single transaction.

This ensures:

- no database writes during composition
- no database writes during preview
- no partially executed child scenarios
- rollback behavior remains centralized in `ScenarioExecutor`

## Test Strategy

Add focused service coverage for:

- ordered merge of two leaf scenarios
- parent input mappings
- literal child input values
- child defaults
- missing parent input mapping
- rejected cross-child reference
- unknown child scenario
- rejected nested composition
- rejected mixed `plan` plus includes
- duplicate refs rejected during composed preview
- duplicate refs rejected before writes during composed execution
- composition does not write records
- composed preview does not write records
- successful composed execution uses the existing transaction-wrapped path

Keep existing scenario registry, preview, validator, and executor tests passing.

## Documentation Update

Update `docs/architecture-plan.md` during implementation to record scenario
composition as an implemented vertical slice and retain the explicit
exclusions listed in this design.
