# Ruby base image
FROM ghcr.io/datadog/images-rb/engines/ruby:3.4

# Install dependencies
COPY Gemfile Gemfile.lock catadog.gemspec /app/
WORKDIR /app
RUN bundle install

# Add files
COPY /bin/ /app/bin/
COPY /mocks/ /app/mocks/
COPY entrypoint.rb /

# Set entrypoint
ENTRYPOINT ["ruby", "/entrypoint.rb"]