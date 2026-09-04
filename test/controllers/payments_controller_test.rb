
require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @payment = payments(:one)
    @user = users(:one)
    sign_in @user
  end

  test "should show payment" do
    get payment_url(@payment.enrollment)

    assert_redirected_to learning_course_path(@payment.enrollment.course)
  end

  test "should create payment" do
    post create_payment_url(@payment.enrollment)

    assert_response :redirect
  end

  test "should get success" do
    get payment_success_url(@payment.enrollment)

    assert_response :success
  end

  test "should get failed" do
    get payment_failed_url(@payment.enrollment)

    assert_response :success
  end
end