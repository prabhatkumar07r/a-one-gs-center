require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest

  setup do
    @event = events(:one)

    @user = users(:admin)
    sign_in @user
  end


  test "should get index" do
    get events_path
    assert_response :success
  end


  test "should get show" do
    get event_path(@event)
    assert_response :success
  end


  test "should get new" do
    get new_event_path
    assert_response :success
  end


  test "should get edit" do
    get edit_event_path(@event)
    assert_response :success
  end

end