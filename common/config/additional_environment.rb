# Redmine log ayarları
config.logger = Logger.new(
  File.join('/var/log/redmine', ENV['CONTAINER_NAME'], 'redmine.log'),
  5, # Dosya sayısı
  1_000_000 # Her dosya için maksimum boyut (1MB)
)

# Log seviyesini ayarla
config.logger.level = Logger::INFO

# Log formatını özelleştir
config.logger.formatter = proc do |severity, datetime, progname, msg|
  timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S.%L')
  # Mesajı güvenli hale getir
  safe_msg = msg.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
                   .gsub('"', "'")
                   .gsub("\n", " ")
                   .gsub("\\", "/")
  # JSON formatında log oluştur
  log_entry = {
    timestamp: timestamp,
    level: severity,
    instance: ENV['CONTAINER_NAME'],
    message: safe_msg
  }
  "#{log_entry.to_json}\n"
end