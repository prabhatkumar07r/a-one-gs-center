require "test_helper"

class TestSeriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get test_series_index_url

    assert_response :success
  end

  test "should get show" do
    test_series = test_series(:one)

    get test_series_url(test_series)

    assert_response :success
  end
end