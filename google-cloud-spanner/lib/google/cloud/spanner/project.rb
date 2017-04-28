# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google/cloud/spanner/errors"
require "google/cloud/env"
require "google/cloud/spanner/service"
require "google/cloud/spanner/client"
require "google/cloud/spanner/instance"
require "google/cloud/spanner/database"
require "google/cloud/spanner/range"

module Google
  module Cloud
    module Spanner
      ##
      # # Project
      #
      # Projects are top-level containers in Google Cloud Platform. They store
      # information about billing and authorized users, and they contain
      # Cloud Spanner data. Each project has a friendly name and a unique ID.
      #
      # Google::Cloud::Spanner::Project is the main object for interacting with
      # Cloud Spanner.
      #
      # {Google::Cloud::Spanner::Instance} and
      # {Google::Cloud::Spanner::Database} objects are created,
      # accessed, and managed by Google::Cloud::Spanner::Project.
      #
      # A {Google::Cloud::Spanner::Client} obtained from a project can be used
      # to read and/or modify data in a Cloud Spanner database.
      #
      # See {Google::Cloud::Spanner.new} and {Google::Cloud#spanner}.
      #
      # @example Obtaining an instance and a database from a project.
      #   require "google/cloud"
      #
      #   spanner = Google::Cloud::Spanner.new
      #   instance = spanner.instance "my-instance"
      #   database = instance.database "my-database"
      #
      # @example Obtaining a client for use with a database.
      #   require "google/cloud/spanner"
      #
      #   spanner = Google::Cloud::Spanner.new
      #
      #   db = spanner.client "my-instance", "my-database"
      #
      #   db.transaction do |tx|
      #     results = tx.execute "SELECT * FROM users"
      #
      #     results.rows.each do |row|
      #       puts "User #{row[:id]} is #{row[:name]}"
      #     end
      #   end
      #
      class Project
        ##
        # @private The Service object.
        attr_accessor :service

        ##
        # @private Creates a new Spanner Project instance.
        def initialize service
          @service = service
        end

        ##
        # The identifier for the Cloud Spanner project.
        #
        # @example
        #   require "google/cloud"
        #
        #   spanner = Google::Cloud::Spanner.new(
        #     project: "my-project-id",
        #     keyfile: "/path/to/keyfile.json"
        #   )
        #
        #   spanner.project #=> "my-project-id"
        #
        def project
          service.project
        end
        alias_method :project_id, :project

        ##
        # @private Default project.
        def self.default_project
          ENV["SPANNER_PROJECT"] ||
            ENV["GOOGLE_CLOUD_PROJECT"] ||
            ENV["GCLOUD_PROJECT"] ||
            Google::Cloud.env.project_id
        end

        ##
        # Retrieves the list of Cloud Spanner instances for the project.
        #
        # @param [String] token The `token` value returned by the last call to
        #   `instances`; indicates that this is a continuation of a call,
        #   and that the system should return the next page of data.
        # @param [Integer] max Maximum number of instances to return.
        #
        # @return [Array<Google::Cloud::Spanner::Instance>] The list of
        #   instances. (See {Google::Cloud::Spanner::Instance::List})
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   instances = spanner.instances
        #   instances.each do |instance|
        #     puts instance.instance_id
        #   end
        #
        # @example Retrieve all: (See {Instance::Config::List::List#all})
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   instances = spanner.instances
        #   instances.all do |instance|
        #     puts instance.instance_id
        #   end
        #
        def instances token: nil, max: nil
          ensure_service!
          grpc = service.list_instances token: token, max: max
          Instance::List.from_grpc grpc, service, max
        end

        ##
        # Retrieves a Cloud Spanner instance by unique identifier.
        #
        # @param [String] instance_id The unique identifier for the instance.
        #
        # @return [Google::Cloud::Spanner::Instance, nil] The instance, or `nil`
        #   if the instance does not exist.
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #   instance = spanner.instance "my-instance"
        #
        # @example Will return `nil` if instance does not exist.
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #   instance = spanner.instance "non-existing" #=> nil
        #
        def instance instance_id
          ensure_service!
          grpc = service.get_instance instance_id
          Instance.from_grpc grpc, service
        rescue Google::Cloud::NotFoundError
          nil
        end

        ##
        # Creates a Cloud Spanner instance and starts preparing it to begin
        # serving.
        #
        # See {Instance::Job}.
        #
        # @param [String] instance_id The unique identifier for the instance,
        #   which cannot be changed after the instance is created. Values are of
        #   the form `[a-z][-a-z0-9]*[a-z0-9]` and must be between 6 and 30
        #   characters in length. Required.
        # @param [String] name The descriptive name for this instance as it
        #   appears in UIs. Must be unique per project and between 4 and 30
        #   characters in length. Required.
        # @param [String, Instance::Config] config The name of the instance's
        #   configuration. Values can be the `instance_config_id`, the full
        #   path, or an {Instance::Config} object. Required.
        # @param [Integer] nodes The number of nodes allocated to this instance.
        #   Required.
        # @param [Hash] labels Cloud Labels are a flexible and lightweight
        #   mechanism for organizing cloud resources into groups that reflect a
        #   customer's organizational needs and deployment strategies. Cloud
        #   Labels can be used to filter collections of resources. They can be
        #   used to control how resource metrics are aggregated. And they can be
        #   used as arguments to policy management rules (e.g. route, firewall,
        #   load balancing, etc.).
        #
        #   * Label keys must be between 1 and 63 characters long and must
        #     conform to the following regular expression:
        #     `[a-z]([-a-z0-9]*[a-z0-9])?`.
        #   * Label values must be between 0 and 63 characters long and must
        #     conform to the regular expression `([a-z]([-a-z0-9]*[a-z0-9])?)?`.
        #   * No more than 64 labels can be associated with a given resource.
        #
        # @return [Instance::Job] The job representing the long-running,
        #   asynchronous processing of an instance create operation.
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   job = spanner.create_instance "my-new-instance",
        #                                 name: "My New Instance",
        #                                 config: "regional-us-central1",
        #                                 nodes: 5,
        #                                 labels: { production: :env }
        #
        #   job.done? #=> false
        #   job.reload! # API call
        #   job.done? #=> true
        #   instance = job.instance
        #
        def create_instance instance_id, name: nil, config: nil, nodes: nil,
                            labels: nil
          config = config.path if config.respond_to? :path
          grpc = service.create_instance \
            instance_id, name: name, config: config, nodes: nodes,
                         labels: labels
          Instance::Job.from_grpc grpc, service
        end

        ##
        # Retrieves the list of instance configurations for the project.
        #
        # @param [String] token The `token` value returned by the last call to
        #   `instance_configs`; indicates that this is a continuation of a call,
        #   and that the system should return the next page of data.
        # @param [Integer] max Maximum number of instance configs to return.
        #
        # @return [Array<Google::Cloud::Spanner::Instance::Config>] The list of
        #   instance configurations. (See
        #   {Google::Cloud::Spanner::Instance::Config::List})
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   instance_configs = spanner.instance_configs
        #   instance_configs.each do |config|
        #     puts config.instance_config_id
        #   end
        #
        # @example Retrieve all: (See {Instance::Config::List::List#all})
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   instance_configs = spanner.instance_configs
        #   instance_configs.all do |config|
        #     puts config.instance_config_id
        #   end
        #
        def instance_configs token: nil, max: nil
          ensure_service!
          grpc = service.list_instance_configs token: token, max: max
          Instance::Config::List.from_grpc grpc, service, max
        end

        ##
        # Retrieves an instance configuration by unique identifier.
        #
        # @param [String] instance_config_id The instance configuration
        #   identifier. Values can be the `instance_config_id`, or the full
        #   path.
        #
        # @return [Google::Cloud::Spanner::Instance::Config, nil] The instance
        #   configuration, or `nil` if the instance configuration does not
        #   exist.
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #   config = spanner.instance_config "regional-us-central1"
        #
        # @example Will return `nil` if instance config does not exist.
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #   config = spanner.instance_config "non-existing" #=> nil
        #
        def instance_config instance_config_id
          ensure_service!
          grpc = service.get_instance_config instance_config_id
          Instance::Config.from_grpc grpc
        rescue Google::Cloud::NotFoundError
          nil
        end

        ##
        # Retrieves the list of databases for the project.
        #
        # @param [String] instance_id The unique identifier for the instance.
        # @param [String] token The `token` value returned by the last call to
        #   `databases`; indicates that this is a continuation of a call,
        #   and that the system should return the next page of data.
        # @param [Integer] max Maximum number of databases to return.
        #
        # @return [Array<Google::Cloud::Spanner::Database>] The list of
        #   databases. (See {Google::Cloud::Spanner::Database::List})
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   databases = spanner.databases "my-instance"
        #   databases.each do |database|
        #     puts database.database_id
        #   end
        #
        # @example Retrieve all: (See {Instance::Config::List::List#all})
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   databases = spanner.databases "my-instance"
        #   databases.all do |database|
        #     puts database.database_id
        #   end
        #
        def databases instance_id, token: nil, max: nil
          ensure_service!
          grpc = service.list_databases instance_id, token: token, max: max
          Database::List.from_grpc grpc, service, instance_id, max
        end

        ##
        # Retrieves a database by unique identifier.
        #
        # @param [String] instance_id The unique identifier for the instance.
        # @param [String] database_id The unique identifier for the database.
        #
        # @return [Google::Cloud::Spanner::Database, nil] The database, or `nil`
        #   if the database does not exist.
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #   database = spanner.database "my-instance", "my-database"
        #
        # @example Will return `nil` if instance does not exist.
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #   database = spanner.database "my-instance", "my-database" #=> nil
        #
        def database instance_id, database_id
          ensure_service!
          grpc = service.get_database instance_id, database_id
          Database.from_grpc grpc, service
        rescue Google::Cloud::NotFoundError
          nil
        end

        ##
        # Creates a database and starts preparing it to begin serving.
        #
        # See {Database::Job}.
        #
        # @param [String] instance_id The unique identifier for the instance.
        #   Required.
        # @param [String] database_id The unique identifier for the database,
        #   which cannot be changed after the database is created. Values are of
        #   the form `[a-z][a-z0-9_\-]*[a-z0-9]` and must be between 2 and 30
        #   characters in length. Required.
        # @param [Array<String>] statements DDL statements to run inside the
        #   newly created database. Statements can create tables, indexes, etc.
        #   These statements execute atomically with the creation of the
        #   database: if there is an error in any statement, the database is not
        #   created. Optional.
        #
        # @return [Database::Job] The job representing the long-running,
        #   asynchronous processing of a database create operation.
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   job = spanner.create_database "my-instance",
        #                                 "my-new-database"
        #
        #   job.done? #=> false
        #   job.reload! # API call
        #   job.done? #=> true
        #   database = job.database
        #
        def create_database instance_id, database_id, statements: []
          grpc = service.create_database instance_id, database_id,
                                         statements: statements
          Database::Job.from_grpc grpc, service
        end

        ##
        # Creates a Cloud Spanner client. A client is used to read and/or modify
        # data in a Cloud Spanner database.
        #
        # @param [String] instance_id The unique identifier for the instance.
        #   Required.
        # @param [String] database_id The unique identifier for the database.
        #   Required.
        # @param [Hash] pool Settings to control how and when sessions are
        #   managed by the client. The following settings can be provided:
        #
        #   * `:min` (Integer) Minimum number of sessions that the client will
        #     maintain at any point in time. The default is 10.
        #   * `:max` (Integer) Maximum number of sessions that the client will
        #     have at any point in time. The default is 100.
        #   * `:keepalive` (Numeric) The amount of time a session can be idle
        #     before an attempt is made to prevent the idle sessions from being
        #     closed by the Cloud Spanner service. The default is 1800 (30
        #     minutes).
        #   * `:write_ratio` (Float) The ratio of sessions with pre-allocated
        #     transactions to those without. Pre-allocating transactions
        #     improves the performance of writes made by the client. The higher
        #     the value, the more transactions are pre-allocated. The value must
        #     be >= 0 and <= 1. The default is 0.3.
        #   * `:fail` (true/false) When `true` the client raises a
        #     {SessionLimitError} when the client has allocated the `max` number
        #     of sessions. When `false` the client blocks until a session
        #     becomes available. The default is `true`.
        #
        # @return [Client] The newly created client.
        #
        # @example
        #   require "google/cloud/spanner"
        #
        #   spanner = Google::Cloud::Spanner.new
        #
        #   db = spanner.client "my-instance", "my-database"
        #
        #   db.transaction do |tx|
        #     results = tx.execute "SELECT * FROM users"
        #
        #     results.rows.each do |row|
        #       puts "User #{row[:id]} is #{row[:name]}"
        #     end
        #   end
        #
        def client instance_id, database_id, pool: {}
          Client.new self, instance_id, database_id,
                     valid_session_pool_options(pool)
        end

        protected

        ##
        # @private Raise an error unless an active connection to the service is
        # available.
        def ensure_service!
          fail "Must have active connection to service" unless service
        end

        def database_path instance_id, database_id
          Admin::Database::V1::DatabaseAdminClient.database_path(
            project, instance_id, database_id)
        end

        def valid_session_pool_options opts = {}
          { min: opts[:min], max: opts[:max], keepalive: opts[:keepalive],
            write_ratio: opts[:write_ratio], fail: opts[:fail]
          }.delete_if { |_k, v| v.nil? }
        end
      end
    end
  end
end
