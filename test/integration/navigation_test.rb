require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "seed generator navigation exposes no scenario run or export surface" do
    get "/seeder_kit"

    assert_response :success
    assert_select "a[href*='scenario']", count: 0
    assert_select "a", text: /run|export/i, count: 0
    assert_select "button", text: /run|export/i, count: 0
    assert_select "input[type=submit][value*='Run']", count: 0
    assert_select "input[type=submit][value*='Export']", count: 0
  end

  test "former scenario urls are not reachable through the mounted engine" do
    scenario = SeederKit::Scenario.create!(name: "Disconnected prototype")

    assert_unreachable :get, "/seeder_kit/scenarios"
    assert_unreachable :get, "/seeder_kit/scenarios/new"
    assert_unreachable :post, "/seeder_kit/scenarios"
    assert_unreachable :get, "/seeder_kit/scenarios/#{scenario.id}"
    assert_unreachable :post, "/seeder_kit/scenarios/#{scenario.id}/run"
    assert_unreachable :get, "/seeder_kit/scenarios/#{scenario.id}/export"
  end

  private

  def assert_unreachable(method, path)
    public_send(method, path)

    assert_response :not_found, "#{method.upcase} #{path} should not be reachable"
  end
end
