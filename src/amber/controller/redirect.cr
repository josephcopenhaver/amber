module Amber::Controller
  module RedirectControllerMethods
    def redirect_to(path : String, status = 302, query_string = nil, flash = nil)
      query = QueryString.parse(query_string).to_s
      Redirector.new(context).redirect(
        status: status, flash: flash, path: path, query_string: query
      )
    end

    def redirect_to(action : Symbol?, status = 302, query_string = nil, flash = nil)
      query = QueryString.new(query_string).to_s
      Redirector.new(context).redirect(
        status: status, flash: flash, query_string: query, action: action,
      )
    end

    def redirect_to(controller : Symbol?, action : Symbol?, status = 302, query_string = nil, flash = nil)
      query = QueryString.new(query_string).to_s

      Redirector.new(context).redirect(
        status: status, flash: flash, controller: controller, action: action, query_string: query
      )
    end

    def redirect_to(**options)
      Redirector.new(context).redirect(**options)
    end

    def redirect_back(flash = nil )
      Redirector.new(context).redirect(flash: flash, path: context.request.headers["Referer"])
    end
  end

  class Redirector
    def initialize(@context : HTTP::Server::Context)
    end

    def redirect(status : Int32 = 302, flash : Hash(Symbol | String, String)? = nil, **options)
      url = build_url(options)
      write_flash(flash)
      write_headers(status, url)
      halt!
      "Redirecting to #{url}"
    end

    private def build_url(options)
      UrlBuilder.new(**options).to_s
    end

    private def halt!
      @context.halt = true
    end

    private def controller
      @context.request_handler.controller.downcase
    end

    private def write_flash(flash)
      @context.flash.merge! flash.to_h if flash
    end

    private def write_headers(status, url)
      @context.response.headers["Location"] = url
      @context.response.status_code = status
    end
  end

  record QueryString, query_string do

    def self.parse(query_string)
      new(query_string).to_s
    end

    @qs : String

    def initialize(query_string)
      @qs = case query_string
            when String, Nil
              HTTP::Params.parse(query_string.to_s).to_s
            when Hash(String, String)
              HTTP::Params.encode(query_string)
            when NamedTuple(key: Symbol, value: String)
              HTTP::Params.encode(query_string)
            else
              HTTP::Params.parse(query_string.to_s)
            end
    end

    def to_s
      @qs.to_s
    end
  end

  record UrlBuilder,
    domain : String? = nil,
    protocol : String = "http",
    host : String? = Crystal::System.hostname,
    only_path : Bool = true,
    port : Int32 = 80,
    anchor : String = "",
    query_string : String = "",
    path : String? | Symbol? = nil,
    end_slash : Bool = true,
    action : Symbol? = nil,
    controller : Symbol? = nil do

    def to_s
      location = if only_path
                   build_path.to_s
                 else
                   scheme.to_s + hostname.to_s + port_number.to_s + build_path.to_s
                 end
      location.to_s + tail_slash.to_s + query.to_s + anchor_part.to_s
    end

    private def port_number
      if !((protocol == "http" && port == 80) || (protocol == "https" && port == 443))
        ":" + port.to_s
      end
    end

    private def build_path
      if path && action.nil?
        return path.to_s
      elsif controller && action
        return "/#{controller}/#{action}"
      else
        path
      end
    end

    private def query
      "?" + query_string unless query_string.empty?
    end

    private def hostname
      host || domain
    end

    private def scheme
      "#{protocol}://"
    end

    private def anchor_part
      "##{anchor}" unless anchor.empty?
    end

    private def tail_slash
      if end_slash && (build_path.to_s.empty? || build_path.to_s.chars.last == "/")
        "/"
      end
>>>>>>> progress
    end
  end
end
