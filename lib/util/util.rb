require 'net/http'
require 'uri'

# Validator method
def is_valid(payload, t, name, *keys)

  return {
    :ok=>false,
    :reason => 'nil payload is not accepted!',
    :err => Exception.new("payload is nil!")
  } if payload.nil?
  if keys.any?
    path = ''
    temp = nil
    keys.each {
      |key|
      if temp.nil?
        path += key
        return {
            :ok => false,
            :reason => 'Field does not exist',
            :err => Exception.new("Expected field <#{key}> can not be found in #{name}")
        } if payload[key.to_sym].nil? && payload[key].nil?
        temp = payload[key] || payload[key.to_sym]
      else
        path += '.'+key
        return {
            :ok => false,
            :reason => 'Field does not exist',
            :err => Exception.new("Expected field <#{path}> can not be found in #{name}")
        } if temp[key.to_sym].nil? && temp[key].nil?
        temp = temp[key] || temp[key.to_sym]
      end
    }

    temp.is_a?(t.class) ? {:ok => true} : {
        :ok => false,
        :reason => 'Unexpected format!',
        :err => Exception.new("Expected format for #{path} is #{t.class.name}, found #{temp.class.name}")
    }
  else
    payload.is_a?(t.class) ? {:ok => true} : {
        :ok => false,
        :reason => 'Unexpected format!',
        :err => Exception.new("Expected format for #{name} is #{t.class.name}, found #{payload.class.name}")
    }
  end
end
# Main logging handler class
# Others will be derived from it

class Envoy

  # @param params Hash
  # @raise ArgumentError When token is nil
  def initialize(params = {})
    @debug = params.fetch(:debug, false)
    @token = params.fetch(:token, nil)
    raise ArgumentError.new 'Token can not be nil or empty' if @token.nil? || @token.to_s.empty?
    @base_url = params.fetch(:base_url, "https://api.botanalytics.co/v1/")
    @callback = params.fetch(:callback, nil)
  end

  # @param message Object
  def informs(message)
    if @debug
      puts "[Botanalytics Debug]: #{message}"
    end
  end

  # @param err Exception
  # @param reason String
  # @param payload Hash
  def fails(err, reason, payload = nil)
      if @callback.nil?
          puts "[Botanalytics Error]: #{reason['error_message'] || reason  unless reason.nil?}, #{err.message unless err.nil?}...\n#{payload unless payload.nil?}"
      else
          send(@callback, err, reason, payload)
      end
  end

  # @param parchment Hash (required)
  # @param destination String
  # @param word String
  def submits(parchment, destination = 'messages/generic/', word = nil)
      # Uri
      uri = URI.parse(@base_url+destination)
      # Header
      header = {'Content-Type':'application/json', 'Authorization': 'Token '+@token}
      begin
          # Send request
          response = Net::HTTP.post(uri, parchment.to_json, header)
          if response.code == "200" or response.code == "201"
              if word.nil?
                  informs("Successfully logged message(s)...")
              else
                  informs(word)
              end
              return true
          else
              fails(Exception.new('Message(s) can not be logged! StatusCode:'+response.code), JSON.parse(response.body), parchment)
              return false
          end
      rescue Exception => e
          fails(e, 'Error during http request', parchment)
          return false
      end
  end

  protected :informs
  protected :fails
  protected :submits
end