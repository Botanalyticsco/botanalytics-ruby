require_relative "../util/util"
require 'net/https'
require 'uri'
require 'json'
require 'thread'

class SlackRTMApi < Envoy

    def initialize(params={})
        super(params)
        @slack_token = params.fetch(:slack_token, nil)
        raise ArgumentError.new "slack_token can not be nil or empty" if @slack_token.nil? || @slack_token.to_s.empty?
        @path = 'messages/slack/'
        @initialize_path = 'bots/slack/initialize/'
        @active_user = nil
        @active_team = nil
        @async = params.fetch(:async, false)
        informs("Logging enabled for #{self.class.name}...")
        if @async
            require 'concurrent'
            @executor_service = Concurrent::ThreadPoolExecutor.new(
                min_threads: 1,
                max_threads: 2,
                max_queue: 1000,
                fallback_policy: :caller_runs
            )
            @executor_service.post do
                fetch
            end
            informs("Mode: Async...")
        else
            Thread.new do
                fetch
            end
        end
    end

    def fetch
        informs("Initializing slack rtm api bot...")
        wait_interval = 2
        update_interval = 3600
        uri = URI.parse('https://slack.com/api/rtm.start')
        while true
            begin
                response = Net::HTTP.post_form(uri, :token => @slack_token)
                case response
                when Net::HTTPSuccess
                    start_data = JSON.parse(response.body)
                    if start_data['ok']

                        @active_user = start_data['self']['id']
                        @active_team = start_data['team']['id']

                        if submits(start_data, @initialize_path, "Successfully updated bot '#{start_data['self']['name']}' info...")
                            informs("Botanalytics::#{self.class.name} initialized team info successfully...")
                            sleep update_interval
                            wait_interval = 2
                        else
                            sleep wait_interval
                            if wait_interval < 20
                                wait_interval += 3
                            end
                            informs("Botanalytics::#{self.class.name} can not initialize team info, retrying...")
                        end
                    else
                        # nope there is a problem here, try
                        sleep wait_interval
                        if wait_interval < 20
                            wait_interval += 3
                        end
                        informs("Botanalytics::#{self.class.name} can not initialize team info, retrying...")
                    end
                else
                    informs("Botanalytics::#{self.class.name} can not initialize team info, Reason: statuscode:#{response.code} retrying...")
                    sleep wait_interval
                    if wait_interval < 20
                        wait_interval += 3
                    end
                end
            rescue Exception => e
                informs("Botanalytics::#{self.class.name} can not initialize team info due to http error, Error: #{e.message}, retrying...")
                sleep wait_interval
                if wait_interval < 20
                    wait_interval += 3
                end
            end
        end
    end

    # @param payload Hash
    def log_incoming(payload)
        if @active_team.nil? or @active_user.nil?
            fails(Exception.new('team and bot'), 'Not initialized yet...')
        else
            validation = validate(payload)
            if validation[:ok]
                informs('Logging message...')
                payload['is_bot'] = false
                payload['team']= @active_team
                informs(payload)
                if @async
                    @executor_service.post do
                        submits(payload, @path)
                    end
                else
                    submits(payload, @path)
                end
            else
                fails(validation[:err], validation[:reason], payload)
            end
        end
    end

    def log_outgoing(channel_id, message, params = {})
        #thread=None, reply_broadcast=None, msg_payload=None

        if @active_team.nil? or @active_user.nil?
            fails(Exception.new('team and bot'), 'Not initialized yet...')
        else
            thread = params.fetch(:thread, nil)
            reply_broadcast = params.fetch(:reply_broadcast, nil)
            msg_payload = params.fetch(:msg_payload, nil)
            if !msg_payload.nil?
                unless msg_payload.is_a?(Hash)
                    fails(Exception.new("Expected format for msg_payload is Hash found #{msg_payload.class.name}"), 'Unexpected payload format!')
                    return
                end
                msg = msg_payload.clone
                validation = validate(msg)
                if validation[:ok]
                    msg['is_bot'] = true
                    msg['ts'] = (Time.new.to_f*1000).to_s
                    msg['team'] = @active_team
                    msg['user'] = @active_user
                    informs('Logging message...')
                    informs(msg)
                    if @async
                        @executor_service.post do
                            submits(msg, @path)
                        end
                    else
                        submits(msg, @path)
                    end
                else
                    informs("Message does not contain 'type' field. Ignoring...")
                end
            else
                payload = Hash.new
                payload['type'] = 'message'
                payload['channel'] = channel_id
                payload['text'] = message
                payload['thread_ts'] = thread unless thread.nil?
                payload['reply_broadcast'] = reply_broadcast unless reply_broadcast.nil?
                payload['is_bot'] = true
                payload['ts'] = (Time.new.to_f*1000).to_s
                payload['team'] = @active_team
                payload['user'] = @active_user
                if @async
                    @executor_service.post do
                        submits(payload, @path)
                    end
                else
                    submits(payload, @path)
                end
            end
        end
    end


    def validate(payload)
        is_valid(payload, "", 'message', 'type')
    end
    private :fetch
    private :validate
end

class SlackEventApi < Envoy

    def initialize(params={})
        super(params)
        @slack_token = params.fetch(:slack_token, nil)
        raise ArgumentError.new "slack_token can not be nil or empty" if @slack_token.nil? || @slack_token.to_s.empty?
        @path = 'messages/slack/event/'
        @initialize_path = 'bots/slack/initialize/'
        @interactive_path = 'messages/slack/interactive/'
        @active_user = nil
        @active_team = nil
        @async = params.fetch(:async, false)
        informs("Logging enabled for #{self.class.name}...")
        if @async
            require 'concurrent'
            @executor_service = Concurrent::ThreadPoolExecutor.new(
                min_threads: 1,
                max_threads: Concurrent.processor_count * 2 + 1,
                max_queue: Concurrent.processor_count * 1000,
                fallback_policy: :caller_runs
            )
            @executor_service.post do
                fetch
            end
            informs("Mode: Async...")
        else
            Thread.new do
                fetch
            end
        end
        @accepted_types = %w(event_callback interactive_message)
    end

    def fetch
        informs("Initializing slack event api bot...")
        wait_interval = 2
        update_interval = 3600
        uri = URI.parse('https://slack.com/api/rtm.start')
        while true
            begin
                response = Net::HTTP.post_form(uri, :token => @slack_token)
                case response
                when Net::HTTPSuccess
                    start_data = JSON.parse(response.body)
                    if start_data['ok']

                        @active_user = start_data['self']['id']
                        @active_team = start_data['team']['id']

                        if submits(start_data, @initialize_path, "Successfully updated bot '#{start_data['self']['name']}' info...")
                            informs("Botanalytics::#{self.class.name} initialized team info successfully...")
                            sleep update_interval
                            wait_interval = 2
                        else
                            sleep wait_interval
                            if wait_interval < 20
                                wait_interval += 3
                            end
                            informs("Botanalytics::#{self.class.name} can not initialize team info, retrying...")
                        end
                    else
                        # nope there is a problem here, try
                        sleep wait_interval
                        if wait_interval < 20
                            wait_interval += 3
                        end
                        informs("Botanalytics::#{self.class.name} can not initialize team info, retrying...")
                    end
                else
                    informs("Botanalytics::#{self.class.name} can not initialize team info, Reason: statuscode:#{response.code} retrying...")
                    sleep wait_interval
                    if wait_interval < 20
                        wait_interval += 3
                    end
                end
            rescue Exception => e
                informs("Botanalytics::#{self.class.name} can not initialize team info due to http error, Error: #{e.message}, retrying...")
                sleep wait_interval
                if wait_interval < 20
                    wait_interval += 3
                end
            end
        end
    end

    # @param payload Hash
    def log(payload)
        if payload.is_a?(Hash)
            return unless payload['challenge'].nil?
        end

        if @active_team.nil? or @active_user.nil?
            fails(Exception.new('team and bot'), 'Not initialized yet...')
        else
            validation = validate(payload)
            if validation[:ok]
                if @accepted_types.include?(payload['type'])
                    informs('Logging message...')
                    informs(payload)
                    if @async
                        @executor_service.post do
                            submits(payload, payload['type'] == 'event_callback' ? @path : @interactive_path)
                        end
                    else
                        submits(payload, payload['type'] == 'event_callback' ? @path : @interactive_path)
                    end
                else
                    fails(
                        Exception.new("Expected types, #{@accepted_types} but found #{payload['type']}"),
                        'If you are sure this is a new event type, contact us < tech@botanalytics.co >',
                        payload
                    )
                end
            else
                fails(validation[:err], validation[:reason], payload)
            end
        end
    end

    def validate(payload)
        is_valid(payload, "", 'event', 'type')
    end
    private :fetch
    private :validate
end