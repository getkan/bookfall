class AdminProvisioning
  class Error < StandardError; end

  def self.call(environment: ENV)
    username = environment["ADMIN_USERNAME"]
    password = environment["ADMIN_PASSWORD"]
    unless username.is_a?(String) && username.present? && password.is_a?(String) && password.present?
      raise Error, "ADMIN_USERNAME and ADMIN_PASSWORD must be set"
    end

    User.transaction do
      # Lock before reading: a row lock cannot protect an initially empty table.
      connection = User.connection
      case connection.adapter_name
      when "PostgreSQL"
        connection.execute("LOCK TABLE users IN SHARE ROW EXCLUSIVE MODE")
      when "SQLite"
        connection.execute("UPDATE users SET id = id WHERE 1 = 0")
      else
        raise Error, "Admin provisioning requires PostgreSQL or SQLite"
      end
      raise Error, "An admin already exists; provisioning will not overwrite it" if User.where(is_admin: true).exists?
      raise Error, "The configured username already exists; provisioning will not promote it" if User.exists?(username: username)

      User.create!(username: username, password: password, is_admin: true)
    end
  end
end
