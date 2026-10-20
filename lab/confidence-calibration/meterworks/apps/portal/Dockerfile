FROM ruby:3.3-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile ./
RUN bundle install --without test
COPY . .
USER 1000
CMD ["bundle", "exec", "puma", "-p", "9292"]
