require "test_helper"

class Admin::TestimonialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
  end

  test "should get index" do
    get admin_testimonials_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_testimonial_url
    assert_response :success
  end

  test "should get edit" do
    testimonial = testimonials(:one)
    get edit_admin_testimonial_url(testimonial)
    assert_response :success
  end
end