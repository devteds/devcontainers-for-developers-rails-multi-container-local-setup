# syntax = docker/dockerfile:1

# Stage 1: Builder (base image that can be used for local deve or to run unit tests on CI)
FROM ruby:3.2.4 as builder
RUN mkdir /workspace
WORKDIR /workspace
RUN apt-get update -qq && \
    apt-get -y install build-essential
ADD Gemfile /workspace/Gemfile
ADD Gemfile.lock /workspace/Gemfile.lock
RUN bundle install

# Stage 2: develop (for local development setup)
FROM builder as develop
WORKDIR /workspace
CMD [ "bundle", "exec", "rails", "s", "-b", "0.0.0.0" ]

# Stage 3: prod-build (intermediate stage that builds prod artifacts)
FROM builder as prod-build
COPY . /workspace
RUN rails assets:precompile
RUN bundle config set --local without 'development test' && \
    bundle config set --local path /rubygems
RUN bundle install

# Stage 4: prod (image that will be deployed all of the environments - qa, staging, prod etc.)
FROM ruby:3.2.4-slim as prod
RUN mkdir /workspace
WORKDIR /workspace
COPY --from=prod-build /workspace /workspace
COPY --from=prod-build /rubygems /rubygems
COPY --from=prod-build /usr/lib/aarch64-linux-gnu/libmariadb.so.3 /usr/lib/aarch64-linux-gnu/libmariadb.so.3
RUN bundle config set --local without 'development test' && \
    bundle config set --local path /rubygems
# RUN useradd rails --create-home --shell /bin/bash && \
#     chown -R rails:rails db log storage tmp
# USER rails:rails    
CMD [ "bundle", "exec", "rails", "s", "-b", "0.0.0.0" ]
