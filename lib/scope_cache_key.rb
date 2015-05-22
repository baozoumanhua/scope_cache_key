require "scope_cache_key/version"

# Add support for passing models and scopes as cache keys.
# The cache key will include the md5 digest of the ids and
# timestamps. Any modification to the group of records will
# generate a new key.
#
# Eg.:
#
#   cache [ Community.first, Category.active ] do ...
#
# Will use the key: communites/1/categories/0b27dac757428d88c0f3a0298eb0278f
module ScopeCacheKey
  # Compute the cache key of a group of records.
  #
  #   Item.cache_key # => "0b27dac757428d88c0f3a0298eb0278f"
  #   Item.active.cache_key # => "0b27dac757428d88c0f3a0298eb0278e"
  #

  if defined?(Rails) and Rails.cache
    def __scope_cache_key_cache_fetch *args, &block
      Rails.cache.fetch(*args, &block)
    end
  else
    def __scope_cache_key_cache_fetch *args
      yield
    end

  end

  def cache_key
    if connection.adapter_name == 'PostgreSQL'
      scope_sql = select("#{table_name}.id, #{table_name}.updated_at").to_sql
      sql = "SELECT md5(array_agg(id || '-' || updated_at)::text) FROM (#{scope_sql}) as query"
    elsif connection.adapter_name == 'Mysql2'
      scope = all
      if scope.offset_value
        scope_sql = scope.select("concat(`#{table_name}`.`id`, '-', `#{table_name}`.`updated_at`) as v0").to_sql
        sql = "SELECT md5(GROUP_CONCAT(t0.v0 SEPARATOR '|')) FROM (#{scope_sql}) AS t0"
      else
        sql = scope.select("md5(GROUP_CONCAT(#{table_name}.`id` ,'-', #{table_name}.`updated_at` order by #{table_name}.`id` asc SEPARATOR '|'))").to_sql
      end
    end 
    md5 = __scope_cache_key_cache_fetch([:scope_cache_key, sql], expires_in: 10.minutes, race_condition_ttl: 10) do 
      connection.select_value(sql)
    end
    key = md5.present? ? md5 : "empty"

    "#{model_name.cache_key}/#{key}"
  end
end

ActiveRecord::Base.extend ScopeCacheKey
