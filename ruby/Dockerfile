FROM ruby:latest

RUN apt update
RUN apt install -y valgrind

RUN mkdir /app
WORKDIR /app

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
COPY phonetics.gemspec /app/phonetics.gemspec
COPY VERSION /app/VERSION

RUN bundle
RUN apt install -y vim
