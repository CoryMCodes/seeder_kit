module SeederKit
  class ModelsController < ApplicationController
    def index
      render json: SeederKit::SchemaReader.new.call
    end
  end
end
