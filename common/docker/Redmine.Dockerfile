FROM redmine:5.0.2

# Log dizinlerini oluştur
RUN mkdir -p /var/log/redmine

# Redis-rails'i Gemfile'a ekle
RUN echo "gem 'redis-rails', '~> 5.0.2'" >> Gemfile

# Gerekli gem'leri yükle
RUN bundle install

# Log dizini için yetkilendirme
RUN chown -R redmine:redmine /var/log/redmine

# Entrypoint script oluştur
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["rails", "server", "-u", "puma", "-b", "0.0.0.0"] 