require "test_helper"
class CertificatesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @certificate = certificates(:one)
    @user = users(:one)

    sign_in @user
  end

  test "should get show" do
    get certificate_url(@certificate)
    assert_response :success
  end
end