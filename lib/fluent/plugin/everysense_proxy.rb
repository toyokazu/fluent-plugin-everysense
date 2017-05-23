module Fluent::Plugin
  module EverySenseProxy
    require 'uri'
    require 'net/http'
    require 'json'
    require 'time'

    class EverySenseProxyError
    end

    def start_proxy
      log.debug "start everysense proxy #{@url}"

      @uri = URI.parse(@url)
      @https = Net::HTTP.new(@uri.host, @uri.port)
      @https.use_ssl = (@uri.scheme == 'https')
      @session_key = nil
    end

    def shutdown_proxy
      log.debug "shutdown_proxy #{@session_key}"
      delete_session
      @https.finish() if @https.active?
    end

    def error_handler(response, message)
      if response.code != "200"
        log.error error: message
        log.debug "code: #{response.code}"
        log.debug "message: #{response.message}"
        log.debug "body: #{response.body}"
        return false
      end
      return true
    end

    def valid_session?
      # TODO validate @session_key using EverySense API
      if !@session_key.nil?
        if Time.now < @session_expires_in
          return true
        end
      end
      return false
    end

    def create_session_request
      session_req = Net::HTTP::Post.new(@uri + '/session')
      session_req.body = {login_name: @login_name, password: @password}.to_json
      session_req.content_type = 'application/json'
      session_req
    end

    def create_session
      return @session_key if valid_session?
      @session_req ||= create_session_request
      session_res = @https.request(@session_req)
      return nil if !error_handler(session_res, 'create_session failed.')
      @session_key = JSON.parse(session_res.body)["session_key"]
      @session_expires_in = Time.now + 60 * 60 * 12 # assuming time out in a half day
    end

    def delete_session_request
      Net::HTTP::Delete.new(@uri + "/session/#{@session_key}")
    end

    def delete_session
      return if !valid_session?
      del_session_res = @https.request(delete_session_request)
      error_handler(del_session_res, 'delete_session failed.')
    end

    def put_message_request(message)
      put_message_req = Net::HTTP::Post.new(@uri + "/device_data/#{@device_id}")
      put_message_req.body = message
      put_message_req.content_type = "application/#{@format}"
      put_message_req
    end

    def put_message(message)
      log.debug "put_message: #{message}"
      put_message_res = @https.request(put_message_request(message))
      error_handler(put_message_res, "put_message: '#{message}' failed.")
    end

    def target_path
      if !@device_id.nil?
        return "/device_data/#{@device_id}"
      elsif !@recipe_id.nil?
        return "/recipe_data/#{@recipe_id}.#{@format}"
      else
        raise Fluent::ConfigError, "device_id or recipe_id must be specified."
      end
    end

    def get_messages_params
      params = {
        session_key: @session_key,
        from: @from,
        to: @to,
        limit: @limit
      }
      if !@device_id.nil?
        return params
      elsif !@recipe_id.nil?
        return params.merge({keep: @keep, inline: @inline, format: @format})
      else
        raise ConfigError, "device_id or recipe_id must be specified."
      end
    end

    def get_messages_request
      from = Time.parse(@from)
      to = from + @interval
      to = Time.now if to > Time.now
      @to = to.iso8601
      get_messages_req = @uri + target_path
      get_messages_req.query = URI.encode_www_form(get_messages_params)
      log.debug "#{get_messages_req}?#{get_messages_req.query}"
      # currently time window is automatically updated
      #@from = Time.now.iso8601
      @from = @to
      get_messages_req
    end

    def get_messages
      if !valid_session?
        return nil if create_session.nil?
        log.debug "session #{@session_key} created."
      end
      get_messages_res = @https.get(get_messages_request)
      return nil if !error_handler(get_messages_res,"get_messages failed.")
      log.debug "get_message: #{get_messages_res.body}"
      get_messages_res.body
    end
  end
end
