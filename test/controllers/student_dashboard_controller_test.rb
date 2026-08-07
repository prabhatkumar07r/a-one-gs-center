require "test_helper"

class StudentDashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)   # student user
  end

  test "should get index" do
    get student_dashboard_path
    assert_response :success
  end
end