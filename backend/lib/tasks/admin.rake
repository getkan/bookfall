namespace :admin do
  desc "Provision the initial admin from ADMIN_USERNAME and ADMIN_PASSWORD without overwriting accounts"
  task provision: :environment do
    AdminProvisioning.call
    puts "Initial admin provisioned"
  rescue AdminProvisioning::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
    Rails.logger.error("Admin provisioning failed (#{error.class.name})")
    abort(error.is_a?(AdminProvisioning::Error) ? error.message : "Admin provisioning failed validation or uniqueness checks")
  end
end
