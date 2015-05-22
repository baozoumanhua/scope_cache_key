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

  def cache_key
    @cache_key ||= begin
      if connection.adapter_name == 'PostgreSQL'
        scope_sql = where(nil).select("#{table_name}.id, #{table_name}.updated_at").to_sql
        sql = "SELECT md5(array_agg(id || '-' || updated_at)::text) FROM (#{scope_sql}) as query"
      elsif connection.adapter_name == 'Mysql2'
        sql = where(nil).select("md5(GROUP_CONCAT(#{table_name}.`id` ,'-', #{table_name}.`updated_at` order by id asc SEPARATOR '|'))").to_sql
      end 
      
      md5 = Rails.cache.fetch([:scope_cache_key, sql], expires_in: 10.minutes, race_condition_ttl: 10) do 
        connection.select_value(sql)
      end
  
      key = md5.present? ? md5 : "empty"
  
      "#{model_name.cache_key}/#{key}"
    end
  end
end

ActiveRecord::Base.extend ScopeCacheKey
