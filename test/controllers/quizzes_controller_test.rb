require "test_helper"

class QuizzesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
    @course = courses(:one)
  end

  test "should get index" do
    get course_quizzes_path(@course)

    assert_response :success
  end
end