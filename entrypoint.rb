if ARGV.empty? || ARGV == %W[bundle exec catadog]
  exec "bundle exec catadog -h 0.0.0.0"
else
  exec "bundle exec catadog -h 0.0.0.0 #{ARGV.join(" ")}"
end
