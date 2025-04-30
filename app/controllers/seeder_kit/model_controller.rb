module SeederKit
  class ModelController < ApplicatonController
    def index
    models = SeederKit::SchemaReader.new.call
      render json: models
    end
  end
end
