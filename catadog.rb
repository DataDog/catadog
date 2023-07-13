#!/usr/bin/env ruby
# frozen_string_literal: true

require "logger"
require "ipaddr"
require "webrick"
require "rack"
require "sinatra/base"
require "net/http"
require "uri"
require "pry"
require "json"
require "msgpack"
require "base64"

module Datadog
  module Catadog
    class App < Sinatra::Base
      get "/" do
        [200, {"Content-Type" => "text/plain"}, ["app: GET /\n"]]
      end

      post "/" do
        [200, {"Content-Type" => "text/plain"}, ["app: POST /\n"]]
      end
    end

    class Intercept
      def initialize(app)
        @app = app
      end

      def call(env)
        r = Rack::Request.new(env)

        case r.get_header("HTTP_CONTENT_TYPE")
        when "application/json"
          req_d = JSON.parse(r.body.read.tap { r.body.rewind })
        when "application/msgpack"
          req_d = MessagePack.unpack(r.body.read.tap { r.body.rewind })
        end

        status, headers, body = @app.call(env)

        case headers["Content-Type"]
        when "application/json"
          res_d = JSON.parse(body.first)
        when "application/msgpack"
          res_d = MessagePack.unpack(body.first)
        else
          case r.fullpath
          when "/info"
            kind = "info"
            res_d = JSON.parse(body.first)
          when "/v0.7/config"
            kind = "rc"
            res_d = JSON.parse(body.first).tap { |e| e.delete("roots") }
            if res_d.key?("targets")
              res_d["targets"] = Base64.strict_decode64(res_d["targets"])
              res_d["targets"] = JSON.parse(res_d["targets"])
            end
            if res_d.key?("target_files")
              res_d["target_files"].each do |f|
                if f["raw"]
                  f["raw"] = Base64.strict_decode64(f["raw"])
                  begin
                    f["parsed"] = JSON.parse(f["raw"])
                    f.delete("raw")
                  rescue JSON::ParseError
                    nil
                  end
                end
              end
            end
          when "/v0.3/traces", "/v0.4/traces", "/v0.7/traces"
            kind = "traces"
            res_d = JSON.parse(body.first)
          when %r{^/telemetry/proxy/api/v2/}
            kind = "telemetry"
            res_d = JSON.parse(body.first)
          end
        end

        d = {
          kind: kind,
          request: {
            method: r.request_method,
            path: r.fullpath,
            headers: r.each_header.with_object({}) { |(k, v), h| k =~ /HTTP_(.*)/ && h[$1.tr("_", "-").downcase] = v },
            body: req_d
          },
          response: {
            status: status,
            headers: headers,
            body: res_d
          }
        }

        $stdout.write(JSON.pretty_generate(d) << "\n")

        [status, headers, body]
      end
    end

    class Mock
      def initialize(app)
        @app = app
      end

      def call(env)
        r = Rack::Request.new(env)

        @app.call(env)
      end
    end

    class Proxy
      def call(env)
        r = Rack::Request.new(env)

        host = "172.16.182.129"
        port = 8126
        uri = URI.join("http://#{host}:#{port}", r.fullpath)

        Net::HTTP.start(uri.host, uri.port) do |http|
          case env["REQUEST_METHOD"]
          when "HEAD"
            req = Net::HTTP::Head.new(uri)
          when "GET"
            req = Net::HTTP::Get.new(uri)
          when "POST"
            req = Net::HTTP::Post.new(uri)
            req.body = env["rack.input"].read
          when "PUT"
            req = Net::HTTP::Put.new(uri)
            req.body = env["rack.input"].read
          when "PATCH"
            req = Net::HTTP::Patch.new(uri)
            req.body = env["rack.input"].read
          when "DELETE"
            req = Net::HTTP::Delete.new(uri)
            req.body = env["rack.input"].read
          end

          r.each_header do |k, v|
            if k == "HTTP_HOST"
              req["HTTP_HOST"] = "#{host}:#{port}"
            elsif k =~ /HTTP_(.*)/
              header_name = $1.tr("_", "-").downcase
              req[header_name] = v
            end
          end

          res = http.request(req)

          status = Integer(res.code)
          headers = res.each_header.with_object({}) { |(k, v), h| h[k] = v }
          body = res.body

          return [status, headers, [body]]
        end
      end
    end

    class Server
      def initialize(settings, logger:)
        @logger = logger # for Rack

        @server = WEBrick::HTTPServer.new(**options(settings, logger: logger))

        @app = rack_app

        @server.mount_proc("/", method(:handler))
      end

      def start
        trap "INT" do
          @server.shutdown
        end

        @server.start
      end

      private

      def rack_app
        Rack::Builder.new do
          map "/catadog" do
            run App.new
          end

          use Intercept
          use Mock

          run Proxy.new
        end.to_app
      end

      def handler(req, res)
        # https://github.com/rack/rack/blob/8f5c885f7e0427b489174a55e6d88463173f22d2/SPEC.rdoc

        # binding.pry if /config/.match?(req.path_info)
        # binding.pry if /traces/.match?(req.path_info)

        env = {}

        env["REQUEST_METHOD"] = req.request_method
        env["SCRIPT_NAME"] = req.script_name
        env["PATH_INFO"] = req.path_info
        env["QUERY_STRING"] = req.query_string || ""
        env["SERVER_NAME"] = req.request_uri.host
        env["SERVER_PORT"] = req.request_uri.port
        env["SERVER_PROTOCOL"] = (/(HTTP\/\d(?:\.\d)?)/ =~ req.request_line && $1.chomp)
        env["rack.url_scheme"] = req.request_uri.scheme

        # TODO: #body_reader + IO.copy_stream
        # TODO: body { |chunk| }
        if req.body
          input_stream = StringIO.new(req.body.dup.force_encoding("ASCII-8BIT"), "rb")
          env["rack.input"] = input_stream
        else
          env["rack.input"] = StringIO.new
        end

        error_stream = StringIO.new(+"", "w")
        env["rack.errors"] = error_stream

        env["rack.hijack?"] = false

        session = {}
        env["rack.session"] = session

        env["rack.logger"] = @logger if @logger

        # env["rack.multipart.buffer_size"] = 0,

        if req.header.key?("content-length")
          env["CONTENT_LENGTH"] = Integer(req.header["content-length"].last)
        end

        # https://datatracker.ietf.org/doc/html/rfc3875#section-4.1.18
        req.header.each { |k, v| env["HTTP_#{k.tr("-", "_").upcase}"] = v.last }

        status, headers, body = @app.call(env)

        # TODO: do something with rack.errors?

        res.status = status
        headers.each { |k, v| res[k] = v }

        # TODO: handle callable and IO
        res.body = body.join("")
      end

      def options(settings, logger:)
        {
          Logger: logger,
          BindAddress: settings.host.to_s,
          Port: settings.port
          # RequestCallback: request_callback
        }
      end
    end

    class Settings
      attr_accessor \
        :debug,
        :verbosity,
        :host,
        :port

      def initialize
        @debug = false
        @verbosity = 0
        @hostname = IPAddr.new("127.0.0.1")
        @port = 8126
      end

      def to_h
        instance_variables.each_with_object({}) { |k, h| h[k] = instance_variable_get(k) }
      end

      def to_s
        to_h.to_s
      end
    end

    # CLI interface
    class CLI
      class UsageError < StandardError; end

      def initialize(args)
        settings = Settings.new

        while (arg = args.shift)
          case arg
          when "-d", "--debug"
            settings.debug = true
          when "-v", "--verbose"
            settings.verbosity += 1
          when "-h", "--host"
            settings.host = IPAddr.new(args.shift)
          when "-p", "--port"
            settings.port = Integer(args.shift)
          else
            raise UsageError, "invalid argument: #{arg}"
          end
        end

        @settings = settings.freeze
      end

      def run
        logger = Logger.new($stderr, level: log_level)
        logger.debug { "settings: #{@settings}" }

        server = Server.new(@settings, logger: logger)

        server.start
      end

      private

      def log_level
        @settings.debug ? Logger::DEBUG : Logger::INFO
      end
    end
  end
end

Datadog::Catadog::CLI.new(ARGV).run if __FILE__ == $PROGRAM_NAME
