FROM ruby:2.7.1

RUN bundle config --global frozen 1

RUN apt-get update
RUN apt-get install -y mariadb-client

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 9292


CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "9292", "config.ru"]