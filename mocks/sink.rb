class Sink
  def initialize(app)
    @app = app
  end

  def call(env)
    r = Rack::Request.new(env)

    case [r.request_method, r.path]
    in "GET", "/info" then info
    in "POST", %r{^/v(0\.3|0\.4|0\.7)/traces$} then traces
    in "POST", %r{^/telemetry/proxy/} then telemetry
    else
      @app.call(env)
    end
  end

  private

  def traces
    payload = {}

    [200, {"Content-Type" => "application/json"}, [JSON.dump(payload)]]
  end

  def telemetry
    payload = {}

    [200, {"Content-Type" => "application/json"}, [JSON.dump(payload)]]
  end

  def info
    payload = {
      "catadog" => true,
      "version" => "7.54",
      "endpoints" => [
        "/v0.3/traces",
        "/v0.4/traces",
        "/v0.7/traces",
        "/telemetry/proxy"
      ]
    }

    [200, {"Content-Type" => "application/json"}, [JSON.dump(payload)]]
  end
end
