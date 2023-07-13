# cat'a-dog

## Quick start

```
git clone https://github.com/DataDog/catadog
cd catadog
bundle install
bundle exec ruby catadog.rb
```

## Examples

Change listening host and port

```
bundle exec ruby catadog.rb -h 0.0.0.0 -p 8888
```

Change agent host and port to proxy to

```
bundle exec ruby catadog.rb --agent-host 10.1.2.3 --agent-port 8127
```

Silence WEBrick logs (they're on stderr):

```
bundle exec ruby catadog.rb 2>/dev/null
```

Record stuff (they're on stdout):

```
bundle exec ruby catadog.rb > dump.json
```

Select specific areas:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="info")'
bundle exec ruby catadog.rb | jq 'select(.kind=="traces")
bundle exec ruby catadog.rb | jq 'select(.kind=="telemetry")'
bundle exec ruby catadog.rb | jq 'select(.kind=="rc")'
```

Show only request body of traces that have a span name `rack.request`:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="traces") | .request.body | .[] | select(.[].name == "rack.request")'
```

Ask telemetry if appsec is enabled:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="telemetry") | .request.body | .payload.additional_payload | .[] | select(.name == "appsec.enabled")'
```

Ask telemetry the list of reported dependencies and their versions, formatted as tab separated:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="telemetry") | .request.body | .payload.dependencies | .[] | [.name, .version] | @tsv' -r
```

Ask telemetry which integrations are enabled:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="telemetry") | .request.body | .payload.integrations | .[] | select(.enabled)'
```

Show RC client config state as it evolves:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | .request.body.client.state.config_states'
```

Show RC client cached targets as they evolve:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | .request.body.cached_target_files'
```

Show RC targets as they are received:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | .response.body.target_files'
```

Show RC targets in both request and response as they evolve:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | { cached: .request.body.cached_target_files | map(.path), received: .response.body.targets.signed.targets }'
```

Show the contents of the `ASM_DD` product traget as it is received

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | .response.body.target_files | .[] | select(.path | test("ASM_DD"))'
```

Show the contents of the `crs-913-110` rule as it is received:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | .response.body.target_files | .[] | select(.path | test("ASM_DD")) | .parsed.rules | .[] | select(.id == "crs-913-110")'
```

Show the contents of the blocked ips list:

```
bundle exec ruby catadog.rb | jq 'select(.kind=="rc") | .response.body.target_files | .[] | select(.path | test("ASM_DATA/blocked_ips"))'
```

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

























