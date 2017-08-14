require "memcached"

module Amber::Router::Session
  class MemcachedStore < AbstractStore
    getter store : Memcached::Client
    property expire_seconds : Int32
    property key : String
    property session : Amber::Router::Session::SessionHash

    forward_missing_to session

    def initialize(@store, @key, @expire_seconds = 120)
      @session = current_session
    end

    def id
      if session.key?("id")
        session["id"]
      else
        session_id = SecureRandom.uuid
        session["id"] = session_id
        set_session
        session_id
      end
    end

    def changed?
      session.changed
    end

    def destroy
      store.delete(key)
      session.clear
    end

    def update(hash : Hash(String, String))
      hash.each { |ikey, ivalue| session[ikey.to_s] = ivalue }
      set_session
      session
    end

    def set_session
      store.set(key, session.to_json, expire: expire_seconds)
    end

    def current_session
      SessionHash.from_json(store.get(key) || "{}")
    rescue e : JSON::ParseException
      SessionHash.new
    end
  end
end
