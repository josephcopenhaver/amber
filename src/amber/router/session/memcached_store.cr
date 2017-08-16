require "memcached"

module Amber::Router::Session
  class MemcachedStore < AbstractStore
    getter store : Memcached::Client
    property expire_seconds : Int32
    property key : String
    property session_id : String
    property session : Amber::Router::Session::SessionHash
    property cookies : Amber::Router::Cookies::Store

    forward_missing_to session

    def initialize(@store, @cookies, @key, @expire_seconds = 120)
      @session_id = cookies.encrypted[key]
    end

    def session_from_store()
      if @session_id
        SessionHash.from_json(store.get("#{key}:#{session_id}") || "{}")
      else
        SessionHash.new
      end
    rescue e : JSON::ParseException
      SessionHash.new
    end

    def session_to_store
      session[:id] = id
      cookies.encrypted.set(key, session_id, expires: expires_at, http_only: true)
      store.set("#{key}:#{session_id}", session.to_json, expire: expire_seconds)
      puts "new session saved"
    end

    def id
      if @session_id
        puts "existing id"
        session_id
      else
        puts "New session id created"
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
      if @session
        session.clear
      end
    end

    def update(hash : Hash(String, String))
      current_session
      hash.each { |ikey, ivalue| session[ikey.to_s] = ivalue }
      session_to_store
      session
    end

    def set_session
      current_session
      session_to_store
    end

    def expires_at
      (Time.now + expires.seconds) if @expires > 0
    end

    def current_session()
      if ! @session
        if @session_id
          @session = session_from_store
          if (! session.key?("id")) || (session[:id] != session_id)
            # this should never happen, but I am a defensive programmer
            session.clear
            puts "Memcached fetch returned incorrect records"
          end
        else
          @session = SessionHash.new
        end
      end
      session
    end
  end
end
