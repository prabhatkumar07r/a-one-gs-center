
require "test_helper"

class TeacherPanel::ProfileControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    sign_in users(:two)
    get teacher_panel_profile_url
    assert_response :success
  end
end
