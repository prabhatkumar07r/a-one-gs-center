require "test_helper"

class StudentControllerTest < ActionDispatch::IntegrationTest

  setup do
    @student = users(:one)   # student user
    @user = users(:admin)    # admin login
    sign_in @user
  end

  test "should get index" do
    get students_url
    assert_response :success
  end

  test "should get show" do
    get student_url(@student)
    assert_response :success
  end

 test "should create student" do
  assert_difference("User.count") do
    post students_url, params: {
      user: {
        name: "Test Student",
        email: "newstudent@example.com",
        mobile: "9876543212",
        password: "password123",
        role: "student"
      }
    }
  end
end

end