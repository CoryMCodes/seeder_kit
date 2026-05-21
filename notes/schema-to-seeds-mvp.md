# Schema to Seeds MVP

## What We Built

SeederKit now has a first non-AI MVP inside the Rails engine:

```txt
paste Rails schema.rb -> generate a starter db/seeds.rb file
```

The engine root now renders a seed generator page with:

- a textarea for pasted Rails `schema.rb`
- a generate button
- a readonly `seeds.rb` output textarea
- links back to the older scenario and model-inspection pages

The implementation is intentionally simple and deterministic. It does not execute the pasted schema, inspect the host Rails app, use AI, use Faker, or try to understand application validations.

Current service pipeline:

- `SeederKit::SchemaParser`
  - statically parses Rails-generated `schema.rb` text
  - extracts tables, supported columns, defaults, nullability, and foreign keys
  - skips Rails/internal tables such as Active Storage, Action Text, schema migrations, and SeederKit engine tables
- `SeederKit::SeedPlanBuilder`
  - orders tables parent-first using foreign key dependencies
  - raises a clear error for dependency cycles
  - assigns deterministic variable names
- `SeederKit::SeedFileGenerator`
  - emits simple `Model.create!` statements
  - generates one record per included table
  - connects foreign keys with variables such as `user_id: user.id`

The current v1 output is deliberately boring:

```ruby
user = User.create!(
  email: "user@example.com"
)

post = Post.create!(
  title: "Example Title",
  user_id: user.id
)
```

## Why This MVP Exists

The larger SeederKit vision is still AI-assisted scenario orchestration for Rails applications, but that is too large to start with.

The small MVP tests a much narrower question:

```txt
Is instant Rails development data useful enough that developers will try it?
```

This does not prove the whole future vision. It does not prove advanced scenario orchestration, team workflows, CI adoption, or AI-assisted planning.

It does prove and teach smaller, useful things:

- whether the zero-setup workflow feels compelling
- which real schemas break the parser or generator assumptions
- what developers ask for immediately after seeing the generated seeds
- whether `schema.rb -> seeds.rb` is a good wedge into the broader development-data problem

The goal right now is not to design a company or force a market thesis. The goal is to build a useful little tool, put it in front of reality, and see what happens.

## AI-Era Question

One open question was whether this is still useful when AI agents can run apps, click through flows with Playwright, and create data on demand.

The working answer:

```txt
Agents reduce some manual smoke-testing work, but they do not remove the need for deterministic development state.
```

Agents are good at:

- clicking through happy paths
- filling forms
- creating basic records
- smoke testing simple flows
- scaffolding rough fixtures

They are still weak at reliable state orchestration:

- complex relational consistency
- repeatable edge-case state
- multi-user and permission workflows
- temporal states like overdue, expired, stale, failed, pending, or partially synced
- reproducing exact bug states
- large interconnected demo or QA datasets

So the likely future is not:

```txt
AI instead of seed systems
```

It is:

```txt
AI planning + deterministic state generation
```

This is the same architectural boundary from the larger SeederKit idea: AI should help describe or plan desired state, but deterministic code should validate, order, and execute that state.

## Engine vs Web Tool

Another design question was whether the paste-schema MVP belongs inside the Rails engine.

Current state:

- the MVP is implemented in the engine because the repo already had a mounted Rails engine surface
- the core logic is service-oriented enough to be reused elsewhere
- the scenario CRUD and `SchemaReader` work remain in place for the larger engine direction

The desired separation:

```txt
SeederKit core
  parser, graph, planning, validation, seed generation

SeederKit Rails engine
  installable Rails-native tool
  host-app introspection
  future AI-assisted CI/scenario generation

SeederKit web tool
  public paste-schema generator
  no install
  simple webpage
  maybe later mirrors selected engine functionality
```

The next useful refactor is to move the generator services from `app/services/seeder_kit` into `lib/seeder_kit`, then have the engine call the library layer. That would make the same code usable by a future separate web app or CLI without treating the engine UI as the center of the product.

## What This Does Not Try To Solve Yet

V1 intentionally does not support:

- app introspection
- model validations
- enums
- polymorphic associations
- STI
- callbacks
- FactoryBot
- Faker
- workflow execution
- AI planning
- browser-agent setup
- realistic scenario generation

Those are future layers. The current tool should stay small until real usage shows which direction is actually worth expanding.

## Useful Next Questions

Questions to keep asking as the MVP gets tried on real schemas:

- Does the output help someone get their app bootstrapped faster?
- Which unsupported schema features appear most often?
- Do users want better seed files, factories, fixtures, SQL, or something else?
- Do they want one record per model, or enough records to make index pages and dashboards feel populated?
- Is a standalone webpage enough, or do people want a gem/CLI because schemas are private?
- Which parts belong in the public web tool, and which belong only in the installable engine?

The main constraint: do not overbuild from imagination. Let the tiny tool expose the next real problem.
