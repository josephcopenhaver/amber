require "http"

module Amber::Controller
  class Base
    property request : HTTP::Request?
    property response : HTTP::Server::Response?
    property raw_params : HTTP::Params?
    property context : HTTP::Server::Context?

    # delegate params, to: context

    protected def set_context(@context : HTTP::Server::Context)
      self.request = context.request
      self.response = context.response
      self.raw_params = context.params
    end

    protected def params(con : HTTP::Server::Context = context)
      if con.is_a?(HTTP::Server::Context)
        unless con.not_nil!.params_parsed
          p = Amber::Pipe::Params.instance
          p.call(con.not_nil!)
        end
        con.not_nil!.params
      end
    end
  end
end
