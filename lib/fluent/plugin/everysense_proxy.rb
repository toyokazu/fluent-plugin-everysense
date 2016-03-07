module Fluent
  module EverySenseProxy
    require 'uri'
    require 'net/http'
    require 'json'
    require 'time'

    def self.included(base)
      base.desc 'EverySense API URI'
      base.config_param :url, :string, :default => 'https://api.every-sense.com:8001/'
      base.desc 'login_name for EverySense API'
      base.config_param :login_name, :string, :default => nil  # TODO: mandatory option
      base.desc 'password for EverySense API'
      base.config_param :password, :string, :default => nil  # TODO: mandatory option
      base.config_param :device_id, :string, :default => nil  # TODO: mandatory option
      base.config_param :recipe_id, :string, :default => nil
      base.config_param :format, :string, :default => 'json'
      #base.config_param :keep_alive, :integer, :default => 2
      base.config_param :from, :string, :default => Time.now.iso8601
    end

    def start_proxy
      $log.debug "start everysense proxy #{@uri}"

      @uri = URI.parse(@url)
      @https = Net::HTTP.new(@uri.host, @uri.port)
      @https.use_ssl = (@uri.scheme == 'https')
      @session_key = nil
    end

    def shutdown_proxy
      delete_session
    end

    def error_handler(response, message)
      if response.code != "200"
        $log.error :error => message
        $log.debug "code: #{response.code}"
        $log.debug "message: #{response.message}"
        $log.debug "body: #{response.body}"
        return false
      end
      return true
    end

    def valid_session?
      !@session_key.nil? # TODO validate @session_key using EverySense API
    end

    def validate_device
      if @device_id.nil?
        $log.error :error => 'Invalid device id.'
        return false
      end
      return true
    end

    def validate_recipe
      if @recipe_id.nil?
        $log.error :error => 'Invalid recipe id.'
        return false
      end
      return true
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
      return if !validate_device
      put_message_res = @https.request(put_message_request(message))
      error_handler(put_message_res, "put_message: '#{message}' failed.")
    end

    def get_message_request
      get_message_req = @uri + "/device_data/#{@device_id}?session_key=#{@session_key}&from=#{URI.encode_www_form_component(@from)}&to=#{URI.encode_www_form_component(Time.now.iso8601)}"
      @from = (Time.now + 1).iso8601
      get_message_req
    end

    def get_message
      if !valid_session?
        return nil if create_session.nil?
        $log.debug "session #{@session_key} created."
      end
      return nil if !validate_device
      get_message_res = @https.get(get_message_request)
      return nil if !error_handler(get_message_res,"get_message failed.")
      get_message_res.body
    end

    def get_recipe_request
      @uri + "/recipe_data/#{@recipe_id}"
    end

    def get_recipe
      if !valid_session?
        return nil if create_session.nil?
        $log.debug "session #{@session_key} created."
      end
      return nil if !validate_recipe
      get_recipe_res = @https.get(get_recipe_request)
      return nil if !error_handler(get_recipe_res, "get_recipe failed.")
      get_recipe_res.body
    end
  end
end
