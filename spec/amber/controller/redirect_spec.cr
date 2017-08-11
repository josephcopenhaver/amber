require "../../../spec_helper"

module Amber::Controller
  describe Redirector do
    describe "#redirect" do
      it "redirects for for location" do
        request = HTTP::Request.new("GET", "/")
        context = create_context(request)
        redirector = Redirector.new(context)
        options = {path: "/some/path", status: 304}

        result = redirector.redirect(**options)

        context.content.nil?.should eq false
        context.response.status_code.should eq 304
        context.response.headers["location"] = "/some/path"
      end

      context "query string" do
        it "parses query params from a string" do
          request = HTTP::Request.new("GET", "/")
          context = create_context(request)
          redirector = Redirector.new(context)
          options = {path: "/some/path", query_string: "hello=world&none=&val=1", status: 304}

          result = redirector.redirect(**options)

          context.content.nil?.should eq false
          context.response.status_code.should eq 304
          context.response.headers["location"] = "/some/path/?#{HTTP::Params.parse(options[:query_string]).to_s}"
        end
      end

    end
  end

  describe UrlBuilder do
    describe "#to_s" do
      context "when only path is true" do
        it "generates path" do
          path = "/some/path"
          url = UrlBuilder.new(only_path: true, path: path)

          url.to_s.should eq path
        end

        it "it generates root path" do
          url = UrlBuilder.new(only_path: true)

          url.to_s.should eq "/"
        end
      end

      context "when only path is false" do
        it "builds url for host 127.0.0.1" do
          options = {only_path: false, host: "127.0.0.1"}
          url = UrlBuilder.new(**options)

          url.to_s.should eq "http://127.0.0.1/"
        end

        it "builds url with system default host" do
          options = {only_path: false}
          url = UrlBuilder.new(**options)

          url.to_s.should eq "http://#{Crystal::System.hostname}/"
        end

        context "when port is provided" do
          it "does not append port for http" do
            options = {only_path: false, port: 80}
            url = UrlBuilder.new(**options)

            url.to_s.should eq "http://#{Crystal::System.hostname}/"
          end

          it "does not append port for https" do
            options = {only_path: false, protocol: "https", port: 443}
            url = UrlBuilder.new(**options)

            url.to_s.should eq "https://#{Crystal::System.hostname}/"
          end

          it "appends port for other than port 80 and 443" do
            options = {only_path: false, protocol: "https", port: 3000}
            url = UrlBuilder.new(**options)

            url.to_s.should eq "https://#{Crystal::System.hostname}:3000/"
          end
        end

        context "when query string is provided" do
          context "when only path is true" do
            it "appends URL encoded query string" do
              query = HTTP::Params.parse("hello=world").to_s
              options = {only_path: true, query_string: query}
              url = UrlBuilder.new(**options)

              url.to_s.should eq "/?#{query}"
            end

            it "does not append the query string" do
              query_string = ""
              options = {only_path: true, query_string: query_string}
              url = UrlBuilder.new(**options)
              url.to_s.should eq "/"
            end

            it "returns root path for empty query string" do
              options = {only_path: true, query_string: ""}
              url = UrlBuilder.new(**options)
              url.to_s.should eq "/"
            end
          end

          context "when only path is false" do
            it "appends query string to url with host" do
              query_string = HTTP::Params.parse("hello=world").to_s
              options = {only_path: false, query_string: query_string}
              url = UrlBuilder.new(**options)

              url.to_s.should eq "http://#{Crystal::System.hostname}/?#{query_string.to_s}"
            end

            it "does not append query string when nil" do
              options = {only_path: false, query_string: ""}
              url = UrlBuilder.new(**options)
              url.to_s.should eq "http://#{Crystal::System.hostname}/"
            end

            it "does not append query string when nil" do
              options = {only_path: false, query_string: ""}
              url = UrlBuilder.new(**options)
              url.to_s.should eq "http://#{Crystal::System.hostname}/"
            end
          end

          context "with anchor" do
            it "appends anchor when present" do
              options = {only_path: false, anchor: "hello"}
              url = UrlBuilder.new(**options)
              url.to_s.should eq "http://#{Crystal::System.hostname}/#hello"
            end

            it "does not append anchor when blank" do
              options = {only_path: false, anchor: ""}
              url = UrlBuilder.new(**options)
              url.to_s.should eq "http://#{Crystal::System.hostname}/"
            end
          end
        end
      end
    end
  end
end
