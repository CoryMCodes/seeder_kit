module SeederKit
  class SeedGeneratorsController < ApplicationController
    def new
      @schema_text = ""
      @seed_output = ""
    end

    def create
      @schema_text = params[:schema].to_s
      parsed_schema = SchemaParser.new.call(@schema_text)
      seed_plan = SeedPlanBuilder.new.call(parsed_schema)
      @seed_output = SeedFileGenerator.new.call(seed_plan)

      render :new
    rescue SchemaParser::ParseError, SeedPlanBuilder::DependencyCycleError => error
      @error_message = error.message
      @seed_output = ""
      render :new, status: :unprocessable_entity
    end
  end
end
