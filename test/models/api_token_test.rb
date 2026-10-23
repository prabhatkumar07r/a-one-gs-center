
require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "valid token fixture is active" do
    token = api_tokens(:one)

    assert token.active?
    assert_includes ApiToken.active, token
  end

  test "revoked token is inactive" do
    token = api_tokens(:one)

    token.revoke!

    assert_not token.active?
    assert_not_includes ApiToken.active, token
  end

  test "expired token is inactive" do
    token = api_tokens(:one)
    token.update!(expires_at: 1.day.ago)

    assert_not token.active?
    assert_not_includes ApiToken.active, token
  end

  test "token digest must be present" do
    token = ApiToken.new(
      user: users(:one),
      token_digest: nil,
      expires_at: 1.day.from_now
    )

    assert_not token.valid?
    assert_includes token.errors[:token_digest], "can't be blank"
  end

  test "token digest must be unique" do
    token = ApiToken.new(
      user: users(:one),
      token_digest: api_tokens(:two).token_digest,
      expires_at: 1.day.from_now
    )

    assert_not token.valid?
    assert_includes token.errors[:token_digest], "has already been taken"
  end

  test "expiration time is required" do
    token = ApiToken.new(
      user: users(:one),
      token_digest: "unique_test_digest",
      expires_at: nil
    )

    assert_not token.valid?
    assert_includes token.errors[:expires_at], "can't be blank"
  end
end
