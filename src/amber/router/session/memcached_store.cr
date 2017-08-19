require "memcached"

module Amber::Router::Session
  class MemcachedStore < AbstractStore
    getter store : Memcached::Client
    property expires : Int32
    property key : String
    property session_id : String | Nil
    property session : Amber::Router::Session::SessionHash
    property cookies : Amber::Router::Cookies::Store

    forward_missing_to session

    def initialize(@store, @cookies, @key, @expires = 120)
      @session_id = cookies.encrypted[key]
      @session = init_session_from_store
    end

    def init_session_from_store()
      if @session_id
        SessionHash.from_json(store.get("#{key}:#{session_id}") || "{}")
      else
        SessionHash.new
      end
    rescue e : JSON::ParseException
      SessionHash.new
    end

    def id
      if @session_id
        session_id
      else
        @session_id = SecureRandom.uuid
      end
    end

    def changed?
      session.changed
    end

    def destroy
      if @session_id
        store.delete("#{key}:#{session_id}")
        @session_id = nil
      end
      session.clear
    end

    def update(hash : Hash(String, String))
      hash.each { |ikey, ivalue| session[ikey.to_s] = ivalue }
      set_session
      session
    end

    def set_session
      session[:id] = id
      cookies.encrypted.set(key, session_id.to_s, expires: expires_at, http_only: true)
      store.set("#{key}:#{session_id}", session.to_json, expire: expires)
    end

    def expires_at
      (Time.now + expires.seconds) if @expires > 0
    end

    def current_session()
      session
    end
  end
end
