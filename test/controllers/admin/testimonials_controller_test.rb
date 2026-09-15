require "test_helper"

class Admin::TestimonialsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_testimonials_index_url
    assert_response :success
  end

  test "should get new" do
    get admin_testimonials_new_url
    assert_response :success
  end

  test "should get edit" do
    get admin_testimonials_edit_url
    assert_response :success
  end
end
