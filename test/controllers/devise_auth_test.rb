require "test_helper"

class DeviseAuthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "sign_in really authenticates the user" do
    user = users(:one)

    sign_in user

    get course_quizzes_path(courses(:one))

    assert_response :success
  end
end