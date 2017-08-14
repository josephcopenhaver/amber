require "http"
require "logger"
require "json"
require "colorize"
require "secure_random"
require "kilt"
require "kilt/slang"
require "memcached"
require "redis"
require "./amber/**"

module Amber
  class Server
    def self.instance
      @@instance ||= new
    end

    def self.routes
      instance.all_routes
    end

    def self.settings
      instance
    end

    def self.key_generator
      instance.key_generator
    end

    def self.session
      instance.session
    end

    setter project_name : String?
    getter key_generator : Amber::Support::CachingKeyGenerator
    property port : Int32
    property name : String
    property env : String
    property log : Logger
    property secret : String
    property host : String = "0.0.0.0"
    property port_reuse : Bool = false
    getter key_generator : Amber::Support::CachingKeyGenerator
    property pubsub_adapter : WebSockets::Adapters::RedisAdapter.class | WebSockets::Adapters::MemoryAdapter.class
    property memcached_host : String
    property memcached_port : Int32
    property redis_url : String
    property session : Hash(Symbol, Symbol | Int32 | String)
    property ssl_key_file : String?
    property ssl_cert_file : String?

    def initialize
      @app_path = __FILE__
      @name = "amber_project"
      @port = 8080
      @env = "development".to_s
      @log = ::Logger.new(STDOUT)
      @log.level = ::Logger::INFO
      @secret = ENV["SECRET_KEY_BASE"]? || SecureRandom.hex(128)
      @host = "0.0.0.0"
      @port_reuse = true
      @key_generator = Amber::Support::CachingKeyGenerator.new(
        Amber::Support::KeyGenerator.new(secret, 5)
      )
      @pubsub_adapter = WebSockets::Adapters::MemoryAdapter
      @memcached_host = "localhost"
      @memcached_port = 11211
      @redis_url = "redis://localhost:6379"
      @session = {
        :key => "session_id",
        # store can be [:signed_cookie, :encrypted_cookie, :redis, :memcached]
        :store     => :signed_cookie,
        :expires   => 0,
        :secret    => secret,
        :redis_url => "redis://localhost:6379",
        :memcached_host => "localhost",
        :memcached_port => 11211,
      }
    end

    def project_name
      @project_name ||= @name.gsub(/\W/, "_").downcase
    end

    def run
      ENV["PROCESS_COUNT"] ||= "1"
      thread_count = ENV["PROCESS_COUNT"].to_i
      if Cluster.master? && thread_count > 1
        while (thread_count > 0)
          Cluster.fork ({"id" => thread_count.to_s})
          thread_count -= 1
        end
        sleep
      else
        start
      end
    end

    def start
      time = Time.now
      ssl_enabled = ssl_key_file && ssl_cert_file
      scheme = ssl_enabled ? "https" : "http"
      str_host = "#{scheme}://#{host}:#{port}".colorize(:light_cyan).underline
      version = "[Amber #{Amber::VERSION}]".colorize(:light_cyan).to_s
      log.info "#{version} serving application \"#{name}\" at #{str_host}".to_s

      # prepare pipelines for processing and memoize them to gain a little performance
      handler.prepare_pipelines

      server = HTTP::Server.new(host, port, handler)
      server.tls = Amber::SSL.new(ssl_key_file.not_nil!, ssl_cert_file.not_nil!).generate_tls if ssl_enabled

      Signal::INT.trap do
        puts "Shutting down Amber"
        server.close
        exit
      end

      log.info "Server started in #{env.colorize(:yellow)}.".to_s
      log.info "Startup Time #{Time.now - time}\n\n".colorize(:white).to_s
      server.listen(port_reuse)
    end

    def config(&block)
      with self yield self
    end

    def socket_endpoint(path, app_socket)
      WebSockets::Server.create_endpoint(path, app_socket)
    end

    macro routes(valve, scope = "")
      router.draw {{valve}}, {{scope}} do
        {{yield}}
      end
    end

    macro pipeline(valve)
      handler.build {{valve}} do
        {{yield}}
      end
    end

    def handler
      @handler ||= Pipe::Pipeline.new
    end

    def all_routes
      router.all
    end

    private def router
      @router ||= Router::Router.instance
    end
  end

  class Cluster
    def self.fork(env : Hash)
      env["FORKED"] = "1"
      Process.fork { Process.run(PROGRAM_NAME, nil, env, true, false, true, true, true, nil) }
    end

    def self.master?
      (ENV["FORKED"]? || "0") == "0"
    end

    def self.worker?
      (ENV["FORKED"]? || "0") == "1"
    end
  end
end
