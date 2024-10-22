# cat'a-dog

## Quick start

### Using Docker

Run the following command to start a new Docker container with `catadog`.

```
docker run --rm -d --name catadog ghcr.io/datadog/catadog
```

### Global command

Run the following commands to install and run `catadog` locally.

```
gem install catadog
catadog
```

### Per project via a Gemfile

```
cat > Gemfile <<'EOF'
source 'https://rubygems.org'

gem 'catadog'
EOF
bundle install
catadog
```

### For `catadog` development

Run the following commands to install and run `catadog` locally.

```
git clone https://github.com/DataDog/catadog
cd catadog
bundle install
bundle exec catadog
```

### Now start your agent and app!

Remember to do one of the following:

- configure your app's agent connection to hit on the correct port
- configure your agent to listen to another port, have `catadog` listen on 8126 as the default, and point to the new agent's port by using the settings below

## Examples

_**Note that if using Docker, replace `bundle exec catadog` with `docker run ghcr.io/datadog/catadog` in the examples below.**_

Change listening host and port (defaults to 127.0.0.1:8128)

```
bundle exec catadog -h 0.0.0.0 -p 8888
```

Change agent host and port to proxy to (defaults to 127.0.0.1:8126)

```
bundle exec catadog --agent-host 10.1.2.3 --agent-port 8127
```

Silence WEBrick logs (they're on stderr):

```
bundle exec catadog 2>/dev/null
```

Record stuff (they're on stdout):

```
bundle exec catadog > dump.json
```

Record stuff, one file per request:

```
bundle exec catadog --record
```

Use the sink mock, and don't forward to a real agent (mock route misses fall back to 404):

```
bundle exec catadog --mock :Sink --no-forward
```

Bring your own mock! (you can use `--mock` multuiple times)

```
bundle exec catadog --mock /path/to/mock.rb:MockMiddlewareClass --no-forward
```

Run program as a background process

```
bundle exec catadog --daemon
```

Select specific areas:

```
bundle exec catadog | jq 'select(.kind=="info")'
bundle exec catadog | jq 'select(.kind=="traces")
bundle exec catadog | jq 'select(.kind=="telemetry")'
bundle exec catadog | jq 'select(.kind=="rc")'
```

Show only request body of traces that have a span name `rack.request`:

```
bundle exec catadog | jq 'select(.kind=="traces") | .request.body | .[] | select(.[].name == "rack.request")'
```

Ask telemetry if appsec is enabled:

```
bundle exec catadog | jq 'select(.kind=="telemetry") | .request.body | .payload.additional_payload | .[] | select(.name == "appsec.enabled")'
```

Ask telemetry the list of reported dependencies and their versions, formatted as tab separated:

```
bundle exec catadog | jq 'select(.kind=="telemetry") | .request.body | .payload.dependencies | .[] | [.name, .version] | @tsv' -r
```

Ask telemetry which integrations are enabled:

```
bundle exec catadog | jq 'select(.kind=="telemetry") | .request.body | .payload.integrations | .[] | select(.enabled)'
```

Show RC client config state as it evolves:

```
bundle exec catadog | jq 'select(.kind=="rc") | .request.body.client.state.config_states'
```

Show RC client cached targets as they evolve:

```
bundle exec catadog | jq 'select(.kind=="rc") | .request.body.cached_target_files'
```

Show RC targets as they are received:

```
bundle exec catadog | jq 'select(.kind=="rc") | .response.body.target_files'
```

Show RC targets in both request and response as they evolve:

```
bundle exec catadog | jq 'select(.kind=="rc") | { cached: .request.body.cached_target_files | map(.path), received: .response.body.targets.signed.targets }'
```

Show the contents of the `ASM_DD` product traget as it is received

```
bundle exec catadog | jq 'select(.kind=="rc") | .response.body.target_files | .[] | select(.path | test("ASM_DD"))'
```

Show the contents of the `crs-913-110` rule as it is received:

```
bundle exec catadog | jq 'select(.kind=="rc") | .response.body.target_files | .[] | select(.path | test("ASM_DD")) | .parsed.rules | .[] | select(.id == "crs-913-110")'
```

Show the contents of the blocked ips list:

```
bundle exec catadog | jq 'select(.kind=="rc") | .response.body.target_files | .[] | select(.path | test("ASM_DATA/blocked_ips"))'
```

## Using Docker Compose

By leveraging the `docker-compose.yaml` file, you can automatically connect your app to `catadog` and your datadog agent. 

First, [instrument your app](https://docs.datadoghq.com/tracing/trace_collection/automatic_instrumentation/dd_libraries/ruby/#instrument-your-application) with the datadog gem.

Then, include the following environment variables in a `.env` file.

```
DD_ENV=env-name.dev
DD_HOSTNAME=host-name
DD_API_KEY=<api_key>
```

Update your `docker-compose.yaml` such as below.

```
services:
  app:
    ...
  catadog:
    image: ghcr.io/datadog/catadog:latest
    command: --agent-host agent
    depends_on:
      - agent
    ports:
      - "8126:8128"
  agent:
    image: datadog/agent
    env_file:
      - ".env"
    environment: 
      - DD_APM_ENABLED=true
      - DD_BIND_HOST=0.0.0.0
      - DD_APM_NON_LOCAL_TRAFFIC=true
      - DD_REMOTE_CONFIGURATION_ENABLED=true
```

Run the following commands.

```
docker compose build
docker compose up -d
```

Finally, see your app send traces to `catadog`!

## The big idea

*dd-trace-cat*

- at [DataDog/dd-trace-cat](https://github.com/DataDog/dd-trace-cat)
- node project
- sink for `/v0.4/traces` *only*
- dumb '200 OK' as response

*catadog*

- support everything else
- decode known encoded content
- use Unix as IDE
- answer properly

TODO:

- *cli*: better interface (command args)
- *traces*: output .dot format (graphviz + sixel)
- *traces*: GUI like dd-trace-cat
- *all*: mock (static, dynamic)
- *all*: record, replay
