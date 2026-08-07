require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @payment = payments(:one)
    @user = users(:admin)
    sign_in @user
  end

  test "should show payment" do
    get payment_url(@payment)
    assert_response :success
  end

  test "should create payment" do
    post payments_url, params: {
      payment: {
        enrollment_id: @payment.enrollment_id,
        amount: @payment.amount,
        razorpay_order_id: @payment.razorpay_order_id,
        razorpay_payment_id: @payment.razorpay_payment_id,
        razorpay_signature: @payment.razorpay_signature,
        status: @payment.status
      }
    }

    assert_response :success
  end

  test "should get success" do
    get success_payment_url(@payment)
    assert_response :success
  end

  test "should get failed" do
    get failed_payment_url(@payment)
    assert_response :success
  end
end