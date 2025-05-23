# Clickhouse::Activerecord

A Ruby database ActiveRecord driver for ClickHouse. Support Rails >= 7.1.
Support ClickHouse version from 22.0 LTS.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'clickhouse-activerecord'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install clickhouse-activerecord
    
## Available database connection parameters
```yml
default: &default
  adapter: clickhouse
  database: database
  host: localhost
  port: 8123
  username: username
  password: password
  ssl: true # optional for using ssl connection
  debug: true # use for showing in to log technical information
  migrations_paths: db/clickhouse # optional, default: db/migrate_clickhouse
  cluster_name: 'cluster_name' # optional for creating tables in cluster 
  replica_name: '{replica}' # replica macros name, optional for creating replicated tables
  read_timeout: 300 # change network timeouts, by default 60 seconds
  write_timeout: 300
  keep_alive_timeout: 300
```

Alternatively if you wish to pass a custom `Net::HTTP` transport (or any other
object which supports a `.post()` function with the same parameters as
`Net::HTTP`'s), you can do this directly instead of specifying
`host`/`port`/`ssl`:

```ruby
class ActionView < ActiveRecord::Base
  establish_connection(
    adapter: 'clickhouse',
    database: 'database',
    connection: Net::HTTP.start('http://example.org', 8123)
  )
end
```

## Usage in Rails

Add your `database.yml` connection information with postfix `_clickhouse` for you environment:

```yml
development:
  adapter: clickhouse
  database: database
```

Your model example:

```ruby
class Action < ActiveRecord::Base
end
```

For materialized view model add:
```ruby
class ActionView < ActiveRecord::Base
  self.is_view = true
end
```

## Usage in Rails with second database

Add your `database.yml` connection information for you environment:

```yml
development:
  primary:
    ...
    
  clickhouse:
    adapter: clickhouse
    database: database
```

Connection [Multiple Databases with Active Record](https://guides.rubyonrails.org/active_record_multiple_databases.html) or short example:

```ruby
class Action < ActiveRecord::Base
  establish_connection :clickhouse
end
```

### Rake tasks

Create / drop / purge / reset database:
 
    $ rake db:create
    $ rake db:drop
    $ rake db:purge
    $ rake db:reset

Or with multiple databases:

    $ rake db:create:clickhouse
    $ rake db:drop:clickhouse
    $ rake db:purge:clickhouse
    $ rake db:reset:clickhouse
    
Migration:

    $ rails g clickhouse_migration MIGRATION_NAME COLUMNS
    $ rake db:migrate
    $ rake db:rollback

### Dump / Load for multiple using databases

If you using multiple databases, for example: PostgreSQL, Clickhouse.

Schema dump to `db/clickhouse_schema.rb` file:

    $ rake db:schema:dump:clickhouse
    
Schema load from `db/clickhouse_schema.rb` file:

    $ rake db:schema:load:clickhouse

For export schema to PostgreSQL, you need use:

    $ rake clickhouse:schema:dump -- --simple

Schema will be dump to `db/clickhouse_schema_simple.rb`. If default file exists, it will be auto update after migration.
    
Structure dump to `db/clickhouse_structure.sql` file:

    $ rake clickhouse:structure:dump
    
Structure load from `db/clickhouse_structure.sql` file:

    $ rake clickhouse:structure:load

### Dump / Load for only Clickhouse database using

    $ rake db:schema:dump  
    $ rake db:schema:load  
    $ rake db:structure:dump  
    $ rake db:structure:load

### RSpec

For auto truncate tables before each test add to `spec/rails_helper.rb` file:

```
require 'clickhouse-activerecord/rspec'
```
    
### Insert and select data

```ruby
Action.where(url: 'http://example.com', date: Date.current).where.not(name: nil).order(created_at: :desc).limit(10)
# Clickhouse Action Load (10.3ms)  SELECT actions.* FROM actions WHERE actions.date = '2017-11-29' AND actions.url = 'http://example.com' AND (actions.name IS NOT NULL)  ORDER BY actions.created_at DESC LIMIT 10
#=> #<ActiveRecord::Relation [#<Action *** >]>

Action.create(url: 'http://example.com', date: Date.yesterday)
# Clickhouse Action Load (10.8ms)  INSERT INTO actions (url, date) VALUES ('http://example.com', '2017-11-28')
#=> true
 
ActionView.maximum(:date)
# Clickhouse (10.3ms)  SELECT maxMerge(actions.date) FROM actions
#=> 'Wed, 29 Nov 2017'

Action.where(date: Date.current).final.limit(10)
# Clickhouse Action Load (10.3ms)  SELECT actions.* FROM actions FINAL WHERE actions.date = '2017-11-29' LIMIT 10
#=> #<ActiveRecord::Relation [#<Action *** >]>

Action.settings(optimize_read_in_order: 1).where(date: Date.current).limit(10)
# Clickhouse Action Load (10.3ms)  SELECT actions.* FROM actions FINAL WHERE actions.date = '2017-11-29' LIMIT 10 SETTINGS optimize_read_in_order = 1
#=> #<ActiveRecord::Relation [#<Action *** >]>

User.joins(:actions).using(:group_id)
# Clickhouse User Load (10.3ms)  SELECT users.* FROM users INNER JOIN actions USING group_id
#=> #<ActiveRecord::Relation [#<User *** >]>

User.window('x', order: 'date', partition: 'name', rows: 'UNBOUNDED PRECEDING').select('sum(value) OVER x')
# SELECT sum(value) OVER x FROM users WINDOW x AS (PARTITION BY name ORDER BY date ROWS UNBOUNDED PRECEDING)
#=> #<ActiveRecord::Relation [#<User *** >]>
```


### Migration Data Types

Integer types are unsigned by default. Specify signed values with `:unsigned =>
false`. The default integer is `UInt32`

| Type (bit size) |                    Range                     | :limit (byte size) |
|:----------------|:--------------------------------------------:|-------------------:|
| Int8            |                 -128 to 127                  |                  1 | 
| Int16           |               -32768 to 32767                |                  2 |
| Int32           |         -2147483648 to 2,147,483,647         |                3,4 |
| Int64           | -9223372036854775808 to 9223372036854775807] |            5,6,7,8 |
| Int128          |                     ...                      |             9 - 15 |
| Int256          |                     ...                      |                16+ |
| UInt8           |                   0 to 255                   |                  1 |
| UInt16          |                 0 to 65,535                  |                  2 |
| UInt32          |              0 to 4,294,967,295              |                3,4 |
| UInt64          |          0 to 18446744073709551615           |            5,6,7,8 |
| UInt256         |                   0 to ...                   |                 8+ |
| Array           |                     ...                      |                ... |
| Map             |                     ...                      |                ... |

Example:

```ruby
class CreateDataItems < ActiveRecord::Migration[7.1]
  def change
    create_table "data_items", id: false, options: "VersionedCollapsingMergeTree(sign, version) PARTITION BY toYYYYMM(day) ORDER BY category", force: :cascade do |t|
      t.date "day", null: false
      t.string "category", null: false
      t.integer "value_in", null: false
      t.integer "sign", limit: 1, unsigned: false, default: -> { "CAST(1, 'Int8')" }, null: false
      t.integer "version", limit: 8, default: -> { "CAST(toUnixTimestamp(now()), 'UInt64')" }, null: false
    end
    
    create_table "with_index", id: false, options: 'MergeTree PARTITION BY toYYYYMM(date) ORDER BY (date)' do |t|
      t.integer :int1, null: false
      t.integer :int2, null: false
      t.date :date, null: false

      t.index '(int1 * int2, date)', name: 'idx', type: 'minmax', granularity: 3
    end
    
    remove_index :some, 'idx'
    
    add_index :some, 'int1 * int2', name: 'idx2', type: 'set(10)', granularity: 4
  end
end
```

Create table with custom column structure and codec compression:

```ruby
class CreateDataItems < ActiveRecord::Migration[7.1]
  def change
    create_table "data_items", id: false, options: "MergeTree PARTITION BY toYYYYMM(timestamp) ORDER BY timestamp", force: :cascade do |t|
      t.integer :user_id, limit: 8, codec: 'DoubleDelta, LZ4'
      t.column "timestamp", "DateTime('UTC') CODEC(DoubleDelta, LZ4)"
    end
  end
end
```

Create Buffer table with connection database name:

```ruby
class CreateDataItems < ActiveRecord::Migration[7.1]
  def change
    create_table :some_buffers, as: :some, options: "Buffer(#{connection.database}, some, 1, 10, 60, 100, 10000, 10000000, 100000000)"
  end
end
```


### Using replica and cluster params in connection parameters

```yml
default: &default
  ***
  cluster_name: 'cluster_name'
  replica_name: '{replica}'
```

`ON CLUSTER cluster_name` will be attach to all queries create / drop.

Engines `MergeTree` and all support replication engines will be replaced to `Replicated***('/clickhouse/tables/cluster_name/database.table', '{replica}')`

## Donations

Donations to this project are going directly to [PNixx](https://github.com/PNixx), the original author of this project:

* BTC address: `1H3rhpf7WEF5JmMZ3PVFMQc7Hm29THgUfN`
* ETH address: `0x6F094365A70fe7836A633d2eE80A1FA9758234d5`
* XMR address: `42gP71qLB5M43RuDnrQ3vSJFFxis9Kw9VMURhpx9NLQRRwNvaZRjm2TFojAMC8Fk1BQhZNKyWhoyJSn5Ak9kppgZPjE17Zh`
* TON address: `UQBt0-s1igIpJoEup0B1yAUkZ56rzbpruuAjNhQ26MVCaNlC`

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Testing github actions:

```bash
act
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/pnixx/clickhouse-activerecord](https://github.com/pnixx/clickhouse-activerecord). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
