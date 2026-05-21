module SeederKit
  class DomainGraphsController < ApplicationController
    def show
      schema = SeederKit::SchemaReader.new.call
      graph = SeederKit::DomainGraphBuilder.new.call(schema)

      render json: graph
    end
  end
end
