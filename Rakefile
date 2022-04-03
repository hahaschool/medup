# frozen_string_literal: true

require "rake/phony"
require "net/http"
require "json"
require "yaml"

def version
  @version ||= begin
    shard = YAML.load_file("shard.yml")
    shard["version"]
  end
end

def crystal_version
  @crytsal_version ||= begin
    shard = YAML.load_file("shard.yml")
    shard["crystal"]
  end
end

task default: %i[test]

desc "Run tests"
task test: :fmt do
  sh "crystal spec"
end

namespace :test do
  task e2e: [:test, :build] do
    sh "crystal spec spec/e2e/cli.cr"
  end
end

desc "Format crystal sources codes"
task :fmt do
  sh "crystal tool format"
end

namespace :fmt do
  desc "Check if code formatted"
  task :check do
    sh "crystal tool format --check"
  end
end

desc "Prepare development environment"
task :setup do
  sh "shards install"
end

desc "Release conatiner image"
task release: %i[test container:push]

APP_NAME = "medup"
OUTPUT_PATH = "_output"
BIN_PATH = "#{OUTPUT_PATH}/#{APP_NAME}"
CONTAINER_IMAGE = "miry/#{APP_NAME}"
directory OUTPUT_PATH

desc "Build app in #{OUTPUT_PATH}"
task build: BIN_PATH

task BIN_PATH => [OUTPUT_PATH] do |t|
  sh "crystal build --release --no-debug -o #{t.name} src/cli.cr"
end

namespace :build do
  task static: [OUTPUT_PATH] do
    sh "crystal build --release --no-debug --static -o #{BIN_PATH} src/cli.cr"
  end
end

desc "Run #{APP_NAME} for provide user and distination via args."
task :run, [:user, :dist] => :build do |t, args|
  args.with_defaults(user: "miry", dist: "posts/medium_miry")
  sh "#{BIN_PATH} -u #{args.user} -d #{args.dist}"
end

namespace :container do
  desc "Build a container image for "
  task :build do
    sh "podman image build " \
       "--build-arg CRYSTAL_VERSION=#{crystal_version} " \
       "-f Containerfile " \
       "--runtime-flag debug " \
       "-t #{CONTAINER_IMAGE}:#{version} " \
       "-t #{CONTAINER_IMAGE}:latest ."
  end

  desc "Push docker image to Hub Docker"
  task push: :build do
    sh "podman image push #{CONTAINER_IMAGE}:#{version}"
    sh "podman image push #{CONTAINER_IMAGE}:latest"
  end

  desc "Test the container image"
  task :test do
    sh "podman container run " \
       "--mount type=tmpfs,tmpfs-size=512M,destination=/posts " \
       "--rm -it #{CONTAINER_IMAGE}:#{version} -u miry"
  end
end

namespace :github do
  desc "Create Github release"
  task :release do
    sh "hub release create -m 'v#{version}' v#{version}"
  end
end

namespace :dev do
  namespace :post do
    desc "Download and format the original JSON of the post"
    task :fetch, [:url] do |t, args|
      uri = URI(args.url)
      uri.query = "format=json" if uri.query.nil?
      response = Net::HTTP.get(uri)
      content = response[16..-1]
      json = JSON.parse(content)

      filename = uri.path.split('/').last + '.json'
      puts "Download to #{filename}"
      open(filename, 'w') do |f|
        f.write(JSON.pretty_generate(json))
      end
    end
  end
end

desc "Run overcommit checks"
task :overcommit do
  sh "bundle check --gemfile=.overcommit_gems.rb || bundle install " \
     "--gemfile=.overcommit_gems.rb"
  sh "bundle exec --gemfile=.overcommit_gems.rb overcommit -r"
end
