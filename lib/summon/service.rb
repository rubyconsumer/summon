
module Summon
  class Service
    
    attr_reader :transport, :url, :access_id, :client_key, :locale, :default_locale
    
    def initialize(options = {})      
      @url        = options[:url] || "http://api.summon.serialssolutions.com"
      @access_id  = options[:access_id]
      @secret_key = options[:secret_key]
      @client_key = options[:client_key]
      @default_locale = 'en'
      @locale     = options[:locale] || @default_locale
      @log        = Log.new(options[:log])
      @transport  = options[:transport] || Summon::Transport::Http.new(:url => @url, :access_id => @access_id, :secret_key => @secret_key, :client_key => @client_key, :session_id => options[:session_id], :log => @log)
    end

    def version
      connect("/version") {|result| result["version"] }
    end    
    
    def search(params = {})
      connect("/search", params) do |result|
        Summon::Search.new(result, @locale)
      end
    end

    def modify_search(original_search, command)
      search original_search.query.to_hash.merge("s.cmd" => command)
    end
    
    #clone a service with overridden options
    def [](options)
      self.class.new({:url => @url, :access_id => @access_id, :secret_key => @secret_key, :client_key => @client_key, :log => @log.impl}.merge(options))
    end

    private
    
    def connect(path, params = {})
      yield @transport.get(path, params)
    end
            
  end
end


