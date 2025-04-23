module SeederKit
  class ScenariosController < ApplicationController
    before_action :set_scenario, only: [ :show, :run, :export ]

    def index
      @scenarios = Scenario.all
    end

    def new
      @scenario = Scenario.new
    end

    def create
    @scenario = Scenario.new(scenario_params)
      if @scenario.save
        redirect_to scenario_path(@scenario), notice: "Scenario Created"
      else
        render :new
      end
    end

    def show
    end

    def run
      # place holder for seed runner
      flash[:notice] = "Ran scenario: #{@scenario.name}"
      redirect_to scenario_path(@scenario)
    end

    def export
      # placeholder to preview/export seed script
      render plain: "# Seed script would be generated here for #{@scenario.name}"
    end
    private

    def set_scenario
      @scenario = SeederKit::Scenario.find(params[:id])
    end

    def scenario_params
      params.require(:scenario).permit(:name, :description)
    end
  end
end
