# [Botanalytics](https://botanalytics.co) - Conversational analytics & engagement tool for chatbots

Ruby SDK currently supports


* [Google Assistant](https://botanalytics.co/docs#google-assistant)
* [Amazon Alexa](https://botanalytics.co/docs#amazon-alexa)
* [Facebook](https://botanalytics.co/docs#facebook-messenger)
* [Slack](https://botanalytics.co/docs#slack)
* [Generic](https://botanalytics.co/docs#generic)

If you want to use nodejs instead, checkout [Botanalytics Node.js SDK](https://github.com/Botanalyticsco/botanalytics)

If you want to use python instead, checkout [Botanalytics Python SDK](https://github.com/Botanalyticsco/botanalytics-python)



## Setup

Create a free account at [https://www.botanalytics.co](https://botanalytics.co) and get a Token.

Botanalytics is available via.

```bash
gem install botanalytics
```

##### Google Assistant
```ruby
require 'botanalytics'

# Optional callback function, if you specify it, you can handle failed
#  attempts the way you want,
def err_callback(err, reason, payload)
    puts err, reason, payload
end    

botanalytics = Botanalytics::GoogleAssistant.new(
                    :debug => true, # Boolean(optional) default=false
                    :token => ENV['BOTANALYTICS_API_TOKEN'], # String(required)
                    :callback => :err_callback, # function(optional) default = logs errors internally
                    :async => true # Boolean(optional) default = false
                )
# request_payload -> Hash, response_payload -> Hash
botanalytics.log(request_payload, response_payload)

```

##### Amazon Alexa
```ruby
require 'botanalytics'

# Optional callback function, if you specify it, you can handle failed
#  attempts the way you want
def err_callback(err, reason, payload)
    puts err, reason, payload
end
    

botanalytics = Botanalytics::AmazonAlexa.new(
                    :debug => true, # Boolean(optional) default=false
                    :token => ENV['BOTANALYTICS_API_TOKEN'], # String(required)
                    :callback => :err_callback, # function(optional) default = logs errors internally
                    :async => true # Boolean(optional) default = false
                )
# request_payload -> Hash, response_payload -> Hash
botanalytics.log(request_payload, response_payload)

```

##### Facebook
```ruby
require 'botanalytics'
require 'json'
require 'webrick'
require 'net/http'
require 'uri'

# Error callback to silence errors or make it louder
def error_callback(err, reason, payload)
    puts err.message, reason, payload
end

# For simplicity
$botanalytics = Botanalytics::FacebookMessenger.new(
                    :debug => true, 
                    :async => true, 
                    :token => ENV['BOTANALYTICS_API_TOKEN'], 
                    :fb_token => ENV['FACEBOOK_PAGE_TOKEN'],
                    :callback => :error_callback
                )
# A dumb handler                
class FacebookHandler
    def self.handle_webhook (request, response)
        payload = JSON.parse(request.body)
        # Log incoming message
        $botanalytics.log_incoming(payload)
        # Entries
        payload['entry'].each { 
            |entry|
            # page_id = entry['id']
            # message_time = entry['time']            
            entry['messaging'].each {
                |event|
                sender_id = event['sender']['id']
                message_to_build= {}
                #
                # Handle your event and build your message
                #
                $botanalytics.log_outgoing(message_to_build, sender_id)
                # send your message
                response_message = {
                    'recipient': {'id':sender_id},
                    'message': message_to_build,
                }
                response = Net::HTTP.post(
                    URI.parse('https://graph.facebook.com/v2.6/me/messages?access_token='+ENV['FACEBOOK_PAGE_TOKEN']),
                    response_message.to_json,
                    {'Content-Type'=>'application/json'}
                )
                case response
                when Net::HTTPSuccess
                    # Success
                else
                    # Handle fail 
                end
            }
        } 
        response.status = 200      
    end  
    def self.handle_rest(request, response)
        puts request.body
        #Handle rest
        response.body = "Page you are looking for..."
        response.status = 404                 
    end
end
# Our simple servlet
class MyServlet < WEBrick::HTTPServlet::AbstractServlet
    
    # Greet
    def do_GET (request, response)
        response.status = 200
        response.body = "Hello There!"
    end

    def do_POST(request, response)
        # Handle your paths
        case request.path
        when "/webhook/facebook"
            FacebookHandler.handle_event(request, response)
        else
            FacebookHandler.handle_rest(request, response)
        end
    end
end

server = WEBrick::HTTPServer.new(:Port => 8000)

server.mount "/", MyServlet

trap("INT") {
    server.shutdown
}

server.start

```


##### Generic
```ruby
require 'botanalytics'

# Optional callback function, if you specify it, you can handle failed
#  attempts the way you want
def err_callback(err, reason, payload)
    puts err, reason, payload
end

# botanalytics
botanalytics = Botanalytics::Generic.new(
                    :debug => true,                          # optional
                    :token => ENV['BOTANALYTICS_API_TOKEN'], # required
                    :callback => :err_callback,              # optional
                    :async => true                           # optional
               )
# message -> Hash
botanalytics.log(message)

```

##### SlackRTMApi
```ruby
require 'botanalytics'
require 'uri'
require 'net/http'
require 'rubygems'
require 'websocket-client-simple'
require 'json'

# will be called if logging fails(optional)
def error_callback(err, reason, payload)
   puts err, reason, payload
end

# botanalytics
$botanalytics = Botanalytics::SlackRTMApi.new(
                    :debug => true,                         # optional
                    :token => ENV['BOTANALYTICS_API_TOKEN'],# required
                    :slack_token => ENV['SLACK_API_TOKEN'], # required
                    :callback => :error_callback,           # optional
                    :async => true                          # optional
                )

# A simple bot that says hello there 
class HelloThereBot
    def initialize(slack_token)
        raise ArgumentError.new("Slack token is not provided!") if slack_token.nil? or slack_token.to_s.empty?
        @slack_token = slack_token
    end
    
    # Start bot
    def start
        puts "Getting slack socket address..."
        uri = URI('https://slack.com/api/rtm.connect')
        while true
            begin
                response = Net::HTTP.post_form(uri, :token => @slack_token)
                case response
                when Net::HTTPSuccess
                    payload = JSON.parse(response.body)
                    puts "Successfully started socket..."
                    handle_client(payload['url'])
                    loop do
                        break if STDIN.gets.to_s.strip == "close" # stop bot 
                    end
                    break
                else
                    puts "Failed to get slack socket address, retrying..."

                end
            rescue Exception => e
                puts e
                puts "Failed to get slack socket address, retrying..."
            end
        end
    end
    
    # socket client handler
    def handle_client(url)
        client = WebSocket::Client::Simple.connect(url)
        # on message
        client.on :message do |msg|  
            unless msg.nil? 
                message = JSON.parse(msg.to_s)
                $botanalytics.log_incoming(message)
                hello = 'Hello there!' # Our ultimate message
                channel = message['channel']
                unless channel.nil?
                    response_message = {'type':'message',
                                        'channel': channel,
                                        'text': hello
                                        }
                    $botanalytics.log_outgoing(channel, message, :thread_ts => nil, :reply_broadcast => nil)
                    client.send(response_message.to_json)
                end
            end
        end
        
        #on open
        client.on :open do
            puts 'Websocket is open!'
        end
        
        #on error
        client.on :error do |e|
            puts e.message
        end
        
        #on close
        client.on :close do
            puts "Nooooo!"
        end
    end
end

# Create bot
bot = HelloThereBot.new(ENV['SLACK_API_TOKEN'])
# Start bot
bot.start
```

##### SlackEventApi
```ruby
require 'botanalytics'
require 'json'
require 'webrick'

# Error callback to silence errors or make it louder
def error_callback(err, reason, payload)
    puts err.message, reason, payload
end

# For simplicity
$botanalytics = Botanalytics::SlackEventApi.new(
                    :debug => true, 
                    :async => true, 
                    :token => ENV['BOTANALYTICS_API_TOKEN'], 
                    :slack_token => ENV['SLACK_API_TOKEN'],
                    :callback => :error_callback
                )
# A dumb handler                
class SlackEventApiHandler
    def self.handle_event (request, response)
        event = JSON.parse(request.body)
        $botanalytics.log(event)
        #
        # Whatever you want
        # 
        response.status = 200
    end

    def self.handle_interactive(request, response)
        str_arr = URI.decode_www_form(request.body, enc='UTF-8')
        event_str = str_arr.at(0).at(1) # interactive event json string
        interactive_event = JSON.parse(event_str)
        $botanalytics.log(interactive_event)
        #
        # Whatever you want
        # 
        response.status = 200
    end
    # Just for fun
    def self.handle_rest(request, response)
        # Handle the rest
        response.status = 404
        response.body = "Sowwy!"
    end
end

# Our simple servlet
class MyServlet < WEBrick::HTTPServlet::AbstractServlet
    
    # Greet
    def do_GET (request, response)
        response.status = 200
        response.body = "Hello There!"
    end

    def do_POST(request, response)
        # Handle your paths
        case request.path
        when "/slack/events"
            SlackEventApiHandler.handle_event(request, response)
        when "/slack/interactive"
            SlackEventApiHandler.handle_interactive(request, response)
        else
            SlackEventApiHandler.handle_rest(request, response)
        end
    end
end

server = WEBrick::HTTPServer.new(:Port => 8000)

server.mount "/", MyServlet

trap("INT") {
    server.shutdown
}

server.start

```
Follow the instructions at [https://botanalytics.co/docs](https://botanalytics.co/docs)
