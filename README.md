# SeederKit
SeederKit is a Rails engine designed to make generating realistic seed data fast, flexible, and repeatable.

Instead of writing brittle seed scripts or hardcoding data, SeederKit provides a structured way to define and generate seed scenarios based on your application’s schema and relationships.

## Why SeederKit Exists
In most Rails apps, seed data quickly becomes:

- Hard to maintain
- Tightly coupled to models
- Difficult to reuse across environments
- Slow to evolve as the schema changes

SeederKit was built to solve that by:

- Separating seed definitions from application logic
- Supporting reusable, composable seed scenarios
- Making it easier to generate consistent, realistic data for development and testing

## Core Concepts
#Scenario-Based Seeding

Define named scenarios that represent real-world states of your application:

```basic_users```
```active_subscriptions```
```enterprise_accounts_with_invoices```

Each scenario encapsulates:

- Models involved
- Relationships
- Data shape and constraints
- Declarative Definitions

Instead of imperative scripts, SeederKit encourages declarative configuration:

- Define what data should look like
- Let the engine handle creation and ordering
- Relationship-Aware

SeederKit is designed to respect model relationships:

- Associations are created in the correct order
- Foreign keys are handled automatically
- Data integrity is preserved

## Installation
Add this line to your application's Gemfile:

```ruby
gem "seeder_kit"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install seeder_kit
```

## Usage
# Define a Scenario
```ruby
SeederKit.define(:basic_users) do
  model :user, count: 10 do
    attribute :email do |i|
      "user#{i}@example.com"
    end

    attribute :name do
      Faker::Name.name
    end
  end
end
```

# Run a Scenario
```bash
rails seeder_kit:run[basic_users]
```

## Example Use Cases
- Quickly bootstrap realistic development environments
- Generate consistent datasets for QA or demos
- Support onboarding by providing ready-to-use data states
- Replace brittle ```db/seeds.rb``` scripts with structured scenarios

## Current Status
SeederKit is an early-stage project focused on:

- Core scenario definition
- Model creation and ordering
- Basic CLI execution

Planned improvements:

- Schema introspection for dynamic model selection
- UI for selecting models and attributes
- More advanced relationship handling
- Integration with test suites

## Design Goals
- Simple: Easy to define and run scenarios
- Composable: Reuse building blocks across scenarios
- Deterministic: Predictable, repeatable outputs
- Rails-native: Works naturally within existing Rails apps
  
## Contributing
This project is actively evolving. Feedback, ideas, and contributions are welcome.

## License
MIT License
