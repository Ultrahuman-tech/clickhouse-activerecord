module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      # Thin wrapper around a TCP client for ClickHouse native protocol.
      # Requires the `ch-client` gem which provides a simple Ruby driver.
      class TcpConnection
        def initialize(host:, port:, username: nil, password: nil, database:, **options)
          require 'clickhouse'
          config = {
            host: host,
            port: port,
            username: username,
            password: password,
            database: database
          }.merge(options)
          @client = ::Clickhouse::Connection.new(config)
        end

        # Execute SQL using the client and wrap the result so it looks like a
        # Net::HTTPResponse object.
        def post(_path, sql, _headers = {})
          data = @client.execute(sql)
          Response.new(data)
        end

        class Response
          attr_reader :body, :code

          def initialize(data)
            @body = data.is_a?(String) ? data : data.to_json
            @code = '200'
          end
        end
      end
    end
  end
end
