require "test_helper"

class TestSeriesResultsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @test_series = test_series(:one)
    @test_series_test = test_series_tests(:one)
    @attempt = test_series_attempts(:one)

    sign_in users(:one)
  end

  test "should get show" do
    get test_series_test_series_test_result_url(
      @test_series,
      @test_series_test,
      @attempt
    )

    assert_response :success
  end
end