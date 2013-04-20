#!/usr/bin/ruby

require 'httpi'
require 'logging'
require 'ostruct'

API_RESPONSES = {
     good: "DNS updated: %s -> %s",
    nochg: "No change to DNS",
  badauth: "Unable to authenticate",
  notfqdn: "Invalid hostname",
   nohost: "Hostname not found",
    abuse: "API abuse",
  unknown: "Unknown API response: %s"
}.freeze

# Logging
log = Logging.logger("loopia.log")
HTTPI.logger = log
log.level = :info

# Config
config_file = File.join(File.dirname(__FILE__), 'loopia.yml')
if File.exists?(config_file)
  log.debug "Loading configuration from #{config_file}"
  config = YAML::load(File.open(config_file))
  config = OpenStruct.new config
else
  log.error "Unable to open #{config_file}. Quiting."
  abort "Unable to open #{config_file}"
end


# Get public IP
log.debug "Fetching current IP"
response = HTTPI.get("http://dns.loopia.se/checkip/checkip.php")
ip = response.body.match(/(?:\d{1,3}\.){3}\d{1,3}/).to_s
log.debug "IP is #{ip}"

# Send update request
log.debug "Updating IP"
url = "http://dns.loopia.se/XDynDNSServer/XDynDNS.php"
request = HTTPI::Request.new(url)
request.auth.basic(config.username, config.password)
hostname = config.hostname.is_a?(Array) ? config.hostname.join(',') : config.hostname
request.query = { hostname: hostname, myip: ip }
response = HTTPI.get(request)

# Handle response
api_code = response.body.downcase.to_sym
case api_code
  when :good, :nochg
    log.error API_RESPONSES[api_code] % [hostname, ip]
    exit 0
  when :badauth, :notfqdn, :nohost
    log.error API_RESPONSES[api_code]
    abort API_RESPONSES[api_code]
  when :abuse
    log.warn API_RESPONSES[api_code]
    abort API_RESPONSES[api_code]
  else
    log.error API_RESPONSES[api_code] % response.body
    abort API_RESPONSES[api_code] % response.body
end
