require "test_helper"
require "timeout"

class AdminProvisioningConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent initial provisioning creates only one admin" do
    User.delete_all
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    pause_insert = lambda do |*args|
      sleep 0.1 if args.last.fetch(:sql).match?(/\AINSERT INTO "users"/)
    end
    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          begin
            user = ActiveSupport::Notifications.subscribed(pause_insert, "sql.active_record") do
              AdminProvisioning.call(environment: {
                "ADMIN_USERNAME" => "concurrent-admin-#{index}",
                "ADMIN_PASSWORD" => "concurrent-provisioning-password"
              })
            end
            results << user
          rescue AdminProvisioning::Error => error
            results << error
          end
        end
      end
    end
    Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:value)
    end
    outcomes = 2.times.map { results.pop }
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(User) }
    errors = outcomes.grep(AdminProvisioning::Error)
    assert_equal 1, errors.size
    assert_match "An admin already exists", errors.first.message
    assert_equal 1, User.where(is_admin: true).count
    assert_equal 1, User.count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
    threads&.each(&:join)
    User.delete_all
  end
end
