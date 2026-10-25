require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "username is required and unique" do
    [ nil, "", " " ].each do |username|
      user = User.new(username: username, password: "model-test-password")
      assert_not user.save
      assert user.errors.of_kind?(:username, :blank)
    end
    duplicate = User.new(username: users(:admin).username, password: "model-test-password")
    assert_not duplicate.save
    assert duplicate.errors.of_kind?(:username, :taken)
  end

  test "password is required protected and confirmed when supplied" do
    user = User.new(username: "model-admin")
    assert_not user.save
    assert user.errors[:password].present?
    user.password = "model-test-password"
    user.password_confirmation = "different-password"
    assert_not user.save
    assert user.errors[:password_confirmation].present?
    user.password_confirmation = user.password
    assert user.save
    assert_not_equal "model-test-password", user.password_digest
    assert user.authenticate("model-test-password")
    assert_not user.authenticate("incorrect")
  end

  test "admin flag defaults false permits true and rejects nil" do
    user = User.new(username: "model-admin", password: "model-test-password")
    assert_equal false, user.is_admin
    assert user.valid?
    user.is_admin = true
    assert user.valid?
    user.is_admin = nil
    assert_not user.save
    assert user.errors[:is_admin].present?
  end

  test "api tokens resolve their user and reject tampering" do
    user = users(:admin)
    token = user.generate_token_for(:api_access)
    assert_equal user, User.find_by_token_for(:api_access, token)
    assert_nil User.find_by_token_for(:api_access, "#{token}tampered")
    assert_nil User.find_by_token_for(:api_access, "invalid")
  end

  test "api tokens expire after twelve hours" do
    travel_to Time.utc(2026, 6, 1)
    token = users(:admin).generate_token_for(:api_access)
    travel 12.hours - 1.second
    assert_equal users(:admin), User.find_by_token_for(:api_access, token)
    travel 2.seconds
    assert_nil User.find_by_token_for(:api_access, token)
  ensure
    travel_back
  end

  test "password changes revoke tokens without requiring password on unrelated updates" do
    user = users(:admin)
    token = user.generate_token_for(:api_access)
    assert user.update(username: "renamed-admin")
    assert_equal user, User.find_by_token_for(:api_access, token)
    assert user.update(password: "new-model-test-password")
    assert_nil User.find_by_token_for(:api_access, token)
    assert_equal user, User.find_by_token_for(:api_access, user.generate_token_for(:api_access))
  end

  test "token lookup returns current role and deleted users cannot authenticate" do
    user = users(:admin)
    token = user.generate_token_for(:api_access)
    user.update!(is_admin: false)
    assert_equal false, User.find_by_token_for(:api_access, token).is_admin
    user.destroy!
    assert_nil User.find_by_token_for(:api_access, token)
  end
end
