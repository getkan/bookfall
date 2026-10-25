require "test_helper"
require "rake"

class AdminProvisioningTest < ActiveSupport::TestCase
  test "provisioning hashes the configured password and grants admin" do
    User.delete_all
    assert_difference("User.count", 1) do
      AdminProvisioning.call(environment: settings)
    end
    user = User.find_by!(username: "initial-admin")
    assert user.is_admin?
    assert user.authenticate("provisioning-test-password")
    assert_not_equal "provisioning-test-password", user.password_digest
  end

  test "missing configuration fails without creating users" do
    User.delete_all
    [ {}, settings.merge("ADMIN_USERNAME" => " "), settings.merge("ADMIN_PASSWORD" => "") ].each do |environment|
      assert_no_difference("User.count") do
        assert_raises(AdminProvisioning::Error) { AdminProvisioning.call(environment: environment) }
      end
    end
  end

  test "reruns cannot overwrite or create another admin" do
    original = users(:admin).attributes
    assert_no_difference("User.count") do
      assert_raises(AdminProvisioning::Error) { AdminProvisioning.call(environment: settings) }
    end
    assert_equal original, users(:admin).reload.attributes
  end

  test "an existing username is not promoted or assigned a new password" do
    user = users(:admin)
    user.update!(is_admin: false)
    original = user.attributes
    assert_raises AdminProvisioning::Error do
      AdminProvisioning.call(environment: settings.merge("ADMIN_USERNAME" => user.username))
    end
    assert_equal original, user.reload.attributes
  end

  test "rake task uses environment and fails explicitly on repeated initialization" do
    User.delete_all
    original = ENV.to_h.slice("ADMIN_USERNAME", "ADMIN_PASSWORD")
    settings.each { |key, value| ENV[key] = value }
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:provision")
    task = Rake::Task["admin:provision"]
    task.reenable
    assert_output("Initial admin provisioned\n") { task.invoke }
    assert User.find_by!(username: "initial-admin").is_admin?
    task.reenable
    assert_output("", /already exists/) do
      error = assert_raises(SystemExit) { task.invoke }
      assert_not error.success?
    end
  ensure
    %w[ADMIN_USERNAME ADMIN_PASSWORD].each { |key| ENV[key] = original[key] } if original
    task&.reenable
  end

  private
    def settings
      { "ADMIN_USERNAME" => "initial-admin", "ADMIN_PASSWORD" => "provisioning-test-password" }
    end
end
