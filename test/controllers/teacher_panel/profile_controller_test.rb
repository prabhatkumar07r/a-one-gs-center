require "test_helper"

class TeacherPanel::ProfileControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get teacher_panel_profile_show_url
    assert_response :success
  end
end
