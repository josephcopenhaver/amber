require "base64"
require "yaml"
require "openssl/hmac"

module Amber
  module Pipe
    class Flash < Base
      PARAM_KEY = "_flash"

      def call(context)
        call_next(context)
      ensure
        flash = context.flash.not_nil!
        context.session[PARAM_KEY] = flash.to_session
      end
    end
  end

  module Router
    module Flash
      def self.from_session_value(flash_content)
        FlashStore.from_session_value(flash_content)
      end

      class FlashNow
        property :flash

        def initialize(@flash)
        end

        def []=(key, value)
          @flash[key] = value
          @flash.discard(key)
          value
        end

        def [](k)
          @flash[k.to_s]
        end

        # Convenience accessor for <tt>flash.now["alert"]=</tt>.
        def alert=(message)
          self["alert"] = message
        end

        # Convenience accessor for <tt>flash.now["notice"]=</tt>.
        def notice=(message)
          self["notice"] = message
        end
      end

      class FlashStore
        include Enumerable(String)

        JSON.mapping({
          flashes: Hash(String, String),
          discard: Set(String),
        })

        def self.from_session_value(json)
          from_json(json)
        rescue e : JSON::ParseException
          new
        end

        delegate :each, to: :flashes

        def initialize
          @flashes = Hash(String, String).new
          @discard = Set(String).new
        end

        def discard=(value : Array(String))
          @discard.merge value
        end

        def []=(key, value)
          @flashes[k.to_s] = value.to_s
        end

        def [](key)
          @discard.add(key = key.to_s)
          @flashes[key]?
        end

        def update(hash : Hash(String, String)) # :nodoc:
          @discard.subtract hash.keys
          # @flashes.update hash 
          self
        end

        def keys
          @flashes.keys
        end

        def has_key?(key)
          @flashes.has_key?(key.to_s)
        end

        def delete(key)
          @discard.delete key.to_s
          @flashes.delete key.to_s
          self
        end

        def to_hash
          @flashes.dup
        end

        def empty?
          @flashes.empty?
        end

        def clear
          @discard.clear
          @flashes.clear
        end

        def now
          @now ||= FlashNow.new(self)
        end

        def keep(key)
          @discard.delete(key = key.to_s)
          @flashes[key]
        end

        def discard(key)
          @discard.add(key = key.to_s)
          @flashes[key]
        end

        def alert
          self["alert"]
        end

        def alert=(message)
          self["alert"] = message
        end

        def notice
          self["notice"]
        end

        def notice=(message)
          self["notice"] = message
        end

        def to_session
          @discard.each { |k| @flashes.delete k }
          @flashes.to_json
        end
      end
    end
  end
end
