require "open3"
require "fileutils"
require "rubygems/package"
require "test_helper"
require "tmpdir"

class GemArtifactTest < ActiveSupport::TestCase
  PROJECT_ROOT = File.expand_path("../..", __dir__)
  REPOSITORY_URL = "https://github.com/CoryMCodes/seeder_kit"
  REQUIRED_FILES = %w[
    CHANGELOG.md
    MIT-LICENSE
    README.md
    SECURITY.md
    app/controllers/seeder_kit/seed_generators_controller.rb
    app/services/seeder_kit/scenario_executor.rb
    app/views/seeder_kit/seed_generators/new.html.erb
    config/routes.rb
    lib/seeder_kit.rb
    lib/seeder_kit/engine.rb
    lib/seeder_kit/version.rb
    lib/tasks/seedier_kit_tasks.rake
  ].freeze
  FORBIDDEN_PATHS = %w[
    .agents/
    .github/
    .worktrees/
    Gemfile
    Gemfile.lock
    Rakefile
    _bmad/
    _bmad-output/
    apps/
    docs/
    notes/
    test/
  ].freeze

  test "built gem has trustworthy public metadata" do
    with_built_gem do |package|
      spec = package.spec

      assert_equal [ "Cory Musick" ], spec.authors
      assert_nil spec.email
      assert_equal REPOSITORY_URL, spec.homepage
      assert_equal "MIT", spec.license
      assert_equal Gem::Requirement.new(">= 3.4", "< 3.5"), spec.required_ruby_version
      assert_equal Gem::Requirement.new(">= 8.0.2", "< 8.1"), spec.runtime_dependencies.find { it.name == "rails" }.requirement

      assert_equal REPOSITORY_URL, spec.metadata.fetch("homepage_uri")
      assert_equal "#{REPOSITORY_URL}/tree/main", spec.metadata.fetch("source_code_uri")
      assert_equal "#{REPOSITORY_URL}/issues", spec.metadata.fetch("bug_tracker_uri")
      assert_equal "#{REPOSITORY_URL}/blob/main/CHANGELOG.md", spec.metadata.fetch("changelog_uri")
      refute spec.metadata.key?("allowed_push_host")

      [ spec.summary, spec.description, *spec.metadata.values ].each do |value|
        refute_empty value
        refute_match(/TODO|yourusername|mygemserver/i, value)
      end
    end
  end

  test "built gem contains the complete narrow runtime artifact" do
    with_built_gem do |package|
      files = package.contents
      missing = REQUIRED_FILES - files
      unexpected = files.select { |file| FORBIDDEN_PATHS.any? { |path| file == path || file.start_with?(path) } }

      assert_empty missing, "Missing required gem contents:\n#{missing.join("\n")}"
      assert_empty unexpected, "Unexpected gem contents:\n#{unexpected.join("\n")}"
      assert_equal files.sort, files, "Gem contents must be sorted deterministically"
    end
  end

  test "CI runs the gem artifact verification independently" do
    workflow = File.read(File.join(PROJECT_ROOT, ".github/workflows/ci.yml"))
    job = workflow[/^  gem-artifact:\n(?<body>.*?)(?=^  [a-z][a-z-]+:|\z)/m, :body]

    assert job, "CI must define an independent gem-artifact job"
    assert_includes job, "ruby-version: ruby-3.4.9"
    assert_includes job, "bin/rails test test/packaging/gem_artifact_test.rb"
    refute_match(/gem push|rake release/, job)
  end

  test "git source installation loads the engine outside the repository bundle" do
    Dir.mktmpdir("seeder-kit-source-install") do |directory|
      source = File.join(directory, "source")
      consumer = File.join(directory, "consumer")
      FileUtils.mkdir_p([ source, consumer ])
      copy_package_source(source)
      initialize_git_source(source)

      File.write(File.join(consumer, "Gemfile"), <<~RUBY)
        source "https://rubygems.org"

        gem "rails", "8.0.2"
        gem "seeder_kit", git: "file://#{source}", branch: "main"
      RUBY

      run_command!(RbConfig.ruby, "-S", "bundle", "install", "--local", chdir: consumer)
      run_command!(
        RbConfig.ruby,
        "-S",
        "bundle",
        "exec",
        "ruby",
        "-e",
        'require "rails"; require "seeder_kit"; abort unless defined?(SeederKit::Engine)',
        chdir: consumer
      )
    end
  end

  private

  def copy_package_source(destination)
    spec = Gem::Specification.load(File.join(PROJECT_ROOT, "seeder_kit.gemspec"))

    [ "seeder_kit.gemspec", *spec.files ].each do |path|
      target = File.join(destination, path)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(PROJECT_ROOT, path), target)
    end
  end

  def initialize_git_source(source)
    run_command!("git", "init", "--initial-branch=main", chdir: source)
    run_command!("git", "add", ".", chdir: source)
    run_command!(
      "git",
      "-c",
      "user.name=SeederKit Test",
      "-c",
      "user.email=test@example.com",
      "commit",
      "-m",
      "Packaging smoke source",
      chdir: source
    )
  end

  def run_command!(*command, chdir:)
    stdout, stderr, status = Open3.capture3(*command, chdir: chdir)
    assert status.success?, "Command failed: #{command.join(" ")}\n#{stdout}\n#{stderr}"
  end

  def with_built_gem
    Dir.mktmpdir("seeder-kit-gem") do |directory|
      artifact = File.join(directory, "seeder_kit.gem")
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        "-S",
        "gem",
        "build",
        "seeder_kit.gemspec",
        "--output",
        artifact,
        chdir: PROJECT_ROOT
      )

      assert status.success?, "Gem build failed:\n#{stdout}\n#{stderr}"
      refute_includes stderr, "for all of the following keys", "Gem build emitted duplicate metadata URI warning:\n#{stderr}"
      yield Gem::Package.new(artifact)
    end
  end
end
