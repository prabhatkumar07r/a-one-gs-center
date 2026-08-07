require "test_helper"

class VideosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)

    @video = videos(:one)
    @playlist = @video.playlist
    @course = @playlist.course
  end

  test "should get index" do
    get course_playlist_videos_url(@course, @playlist)
    assert_response :success
  end

  test "should get new" do
    get new_course_playlist_video_url(@course, @playlist)
    assert_response :success
  end

  test "should create video" do
    assert_difference("Video.count") do
      post course_playlist_videos_url(@course, @playlist), params: {
        video: {
           title: "New Video",
           description: "Test video",
           duration: "20 min",
          position: 1,
           video_url: "https://youtube.com/watch?v=test123",
        course_id: @course.id,
        playlist_id: @playlist.id
}
      }
    end

    assert_redirected_to course_playlist_video_url(
      @course,
      @playlist,
      Video.last
    )
  end

  test "should show video" do
    get course_playlist_video_url(@course, @playlist, @video)
    assert_response :success
  end

  test "should get edit" do
    get edit_course_playlist_video_url(@course, @playlist, @video)
    assert_response :success
  end

  test "should update video" do
    patch course_playlist_video_url(@course, @playlist, @video), params: {
      video: {
        title: @video.title,
        description: @video.description,
        duration: @video.duration
      }
    }

    assert_redirected_to course_playlist_video_url(
      @course,
      @playlist,
      @video
    )
  end

  test "should destroy video" do
    assert_difference("Video.count", -1) do
      delete course_playlist_video_url(@course, @playlist, @video)
    end

    assert_redirected_to course_playlist_videos_url(
      @course,
      @playlist
    )
  end
end