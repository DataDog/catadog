if ARGV.empty? || ARGV == %W[bundle exec catadog]
  exec "bundle exec catadog -h 0.0.0.0"
elsif ARGV[0].start_with?("-")
  exec "bundle exec catadog -h 0.0.0.0 #{ARGV.join(" ")}"
else
  exec ARGV.join(" ").to_s
end
