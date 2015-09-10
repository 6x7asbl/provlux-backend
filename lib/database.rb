require "mysql2"

def mysql
  return @mysql_client if @mysql_client

  # Create and return the client if it does not exist
  @mysql_client = Mysql2::Client.new({
      :host => ENV["MYSQL_HOST"],
      :username => ENV["MYSQL_USERNAME"],
      :password => ENV['MYSQL_PASSWORD'],
      :database => ENV['MYSQL_DATABASE']
    })
    return @mysql_client
end
