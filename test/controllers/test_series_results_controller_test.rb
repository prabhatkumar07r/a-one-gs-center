require "test_helper"

class TestSeriesResultsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get test_series_results_show_url
    assert_response :success
  end
end
