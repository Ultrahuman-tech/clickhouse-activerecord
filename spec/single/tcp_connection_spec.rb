require 'spec_helper'

RSpec.describe 'TCP connection' do
  it 'executes simple query over tcp' do
    config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(protocol: 'tcp')
    ActiveRecord::Base.establish_connection(config)
    expect {
      ActiveRecord::Base.connection.do_execute('SELECT 1')
    }.not_to raise_error
  end
end
