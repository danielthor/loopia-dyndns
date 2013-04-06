#!/usr/bin/ruby

# hostname
# myip
# wildcard=NOCHG

# twitter_config_file = File.join(File.dirname(__FILE__), 'twitter.yml')
# if File.exists?(twitter_config_file)
#   twitter_config = YAML::load(File.open(twitter_config_file))
#   Twitter.configure do |config|
#     config.consumer_key = twitter_config['twitter']['consumer_key']
#     config.consumer_secret = twitter_config['twitter']['consumer_secret']
#     config.oauth_token = twitter_config['twitter']['oauth_token']
#     config.oauth_token_secret = twitter_config['twitter']['oauth_token_secret']
#   end
# end

require 'httpi'
require 'logging'
require 'ostruct'

API_RESPONSES = {
     good: "DNS updated",
    nochg: "No change to DNS",
  badauth: "Unable to authenticate",
  notfqdn: "Invalid hostname",
   nohost: "Hostname not found",
    abuse: "API abuse"
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
api_code = response.body.downcase
case api_code
  when 'good'
    log.info "Updated #{hostname} -> #{ip}"
    exit 1
  when 'nochg'
    log.debug "No change"
    exit 1
  when 'badauth', 'notfqdn', 'nohost'
    log.error API_RESPONSES[api_code.to_sym]
    abort API_RESPONSES[api_code.to_sym]
  when 'abuse'
    log.warn "API abuse"
    abort "API abuse"
  else
    log.error "Unknown API response: #{response.body}"
    abort "Unknown API response: #{response.body}"
end
