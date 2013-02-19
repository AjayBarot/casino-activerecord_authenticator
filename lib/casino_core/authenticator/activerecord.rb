require 'active_record'
require 'unix_crypt'
require 'bcrypt'

class CASinoCore::Authenticator::ActiveRecord

  # @param [Hash] options
  def initialize(options)
    @options = options
    ::ActiveRecord::Base.establish_connection @options[:connection]

    eval <<-END
      class #{@options[:table].classify} < ActiveRecord::Base
      end
    END

    @model = "#{self.class.to_s}::#{@options[:table].classify}".constantize
  end

  def validate(username, password)
    user = @model.send("find_by_#{@options[:username_column]}!", username)
    password_from_database = user.send(@options[:password_column])

    if valid_password?(password, password_from_database)
      { username: user.send(@options[:username_column]) }.merge(extra_attributes(user))
    else
      false
    end

  rescue ActiveRecord::RecordNotFound
    false
  end

  private
  def valid_password?(password, password_from_database)
    magic = password_from_database.split('$')[1]
    case magic
    when /\A2a?\z/
      BCrypt::Password.new(password_from_database) == password
    else
      UnixCrypt.valid?(password, password_from_database)
    end
  end

  def extra_attributes(user)
    attributes = {}
    @options[:extra_attributes].each do |attribute_name, database_column|
      attributes[attribute_name] = user.send(database_column)
    end
    attributes
  end
end
