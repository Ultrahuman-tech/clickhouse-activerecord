module ActiveRecord
  module ConnectionAdapters
    module Clickhouse
      # Thin wrapper around a TCP session using the `clickhouse-client` binary.
      # This avoids relying on a Ruby gem for the native protocol and simply
      # shells out to the official client shipped with ClickHouse.
      class TcpConnection
        def initialize(host:, port:, username: nil, password: nil, database:, **_options)
          require 'open3'
          @host = host
          @port = port || 9000
          @username = username
          @password = password
          @database = database
        end

        # Execute SQL using the `clickhouse-client` command and expose an
        # object compatible with Net::HTTPResponse.
        def post(_path, sql, _headers = {})
          cmd = [
            'clickhouse-client',
            "--host=#{@host}",
            "--port=#{@port}",
            "--database=#{@database}",
            "--query=#{sql}"
          ]
          cmd << "--user=#{@username}" if @username
          cmd << "--password=#{@password}" if @password

          stdout, stderr, status = Open3.capture3(*cmd)
          body = status.success? ? stdout : stderr
          code = status.success? ? '200' : '500'
          Response.new(body, code)
        end

        class Response
          attr_reader :body, :code

          def initialize(body, code)
            @body = body
            @code = code
          end
        end
      end
    end
  end
end
