require "test_helper"

class QuizzesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get quizzes_index_url
    assert_response :success
  end

  test "should get show" do
    get quizzes_show_url
    assert_response :success
  end

  test "should get start" do
    get quizzes_start_url
    assert_response :success
  end

  test "should get submit" do
    get quizzes_submit_url
    assert_response :success
  end

  test "should get result" do
    get quizzes_result_url
    assert_response :success
  end
end
