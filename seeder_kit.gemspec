require_relative "lib/seeder_kit/version"

Gem::Specification.new do |spec|
  spec.name        = "seeder_kit"
  spec.version     = SeederKit::VERSION
  spec.authors     = [ "Cory Musick" ]
  spec.homepage    = "https://github.com/CoryMCodes/seeder_kit"
  spec.summary     = "Define, preview, validate, compose, and execute named development data states in Rails."
  spec.description = "SeederKit is a Rails Engine for deterministic named development data scenarios with side-effect-free preview, validation, shallow composition, and transaction-wrapped execution."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.4", "< 3.5"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "CHANGELOG.md", "MIT-LICENSE", "README.md", "SECURITY.md"]
      .select { |path| File.file?(path) }
      .sort
  end

  spec.add_dependency "rails", ">= 8.0.2", "< 8.1"
end
