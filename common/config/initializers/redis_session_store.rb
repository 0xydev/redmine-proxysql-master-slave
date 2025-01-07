require 'redis-rails'

Rails.application.config.session_store :redis_store,
  servers: {
    host: 'redis',
    port: 6379,
    db: 0,
    namespace: "redmine:session"
  },
  expire_after: 8.hours,
  key: '_redmine_session'