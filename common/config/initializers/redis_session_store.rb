require 'redis-rails'

Rails.application.config.session_store :redis_store,
  servers: {
    host: Rails.configuration.redis_host,
    port: Rails.configuration.redis_port,
    db: Rails.configuration.redis_db_name,
    namespace: "redmine:session"
  },
  expire_after: 8.hours,
  key: '_redmine_session'