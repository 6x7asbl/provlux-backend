require "iron_mq"
def ironmq
  return @ironmq_client if @ironmq_client

  # Create and return the client if it does not exist
  @ironmq_client = ::IronMQ::Client.new(:token => ENV['IRONMQ_TOKEN'], :project_id => ENV['IRONMQ_PROJECT'])
  return @ironmq_client
end
