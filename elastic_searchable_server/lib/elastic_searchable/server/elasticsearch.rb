require 'shellwords'
require 'set'
require 'tempfile'
require 'elastic_searchable/server/java'

module ElasticSearchable
  module Server
    class ElasticSearch
      # Raised if #stop is called but the server is not running
      ServerError = Class.new(RuntimeError)
      AlreadyRunningError = Class.new(ServerError)
      NotRunningError = Class.new(ServerError)
      JavaMissing = Class.new(ServerError)

      ELASTICSEARCH_PATH = File.expand_path(File.join('..', '..', '..', '..', 'elasticsearch'), __FILE__)

      attr_accessor :min_memory, :max_memory, :bind_address, :port

      def initialize(*args)
        ensure_java_installed
        super(*args)
      end

      def start
        bootstrap

        if File.exist?(pid_path)
          existing_pid = IO.read(pid_path).to_i
          begin
            Process.kill(0, existing_pid)
            raise(AlreadyRunningError, "Server is already running with PID #{existing_pid}")
          rescue Errno::ESRCH
            STDERR.puts("Removing stale PID file at #{pid_path}")
            FileUtils.rm(pid_path)
          end
        end
        fork do
          pid = fork do
            Process.setsid
            STDIN.reopen('/dev/null')
            STDOUT.reopen('/dev/null', 'a')
            STDERR.reopen(STDOUT)
            run
          end
          FileUtils.mkdir_p(pid_dir)
          File.open(pid_path, 'w') do |file|
            file << pid
          end
        end
      end

      def run
        bootstrap

        command = [elasticsearch_binary]
        command << '-f'
        FileUtils.cd(File.dirname(elasticsearch_binary)) do
          exec(Shellwords.shelljoin(command))
        end
      end

      def stop
        bootstrap

        if File.exist?(pid_path)
          pid = IO.read(pid_path).to_i
          begin
            Process.kill('TERM', pid)
          rescue Errno::ESRCH
            raise NotRunningError, "Process with PID #{pid} is no longer running"
          ensure
            FileUtils.rm(pid_path)
          end
        else
          raise NotRunningError, "No PID file at #{pid_path}"
        end
      end

      def pid_path
        File.join(pid_dir, pid_file)
      end

      def pid_file
        @pid_file || 'elasticsearch.pid'
      end

      def pid_dir
        File.expand_path(@pid_dir || FileUtils.pwd)
      end

      def elasticsearch_binary
        File.join elasticsearch_path, "bin", "elasticsearch"
      end

      def config_dir
        File.join elasticsearch_path, "config"
      end

      def log_path
        File.join log_dir, 'elasticsearch.log'
      end

      def config_path
        File.join config_dir, "elasticsearch.yml"
      end

      def log_dir
        File.expand_path @log_dir || File.join(elasticsearch_path, 'logs')
      end

      def data_dir
        File.expand_path @data_dir || File.join(elasticsearch_path, 'data')
      end

      def bootstrap
        return if bootstrapped?

        if defined?(Rails) && Rails::VERSION::MAJOR == 3
          @elasticsearch_path = File.join ::Rails.root, "elasticsearch"
          unless File.exists? @elasticsearch_path
            puts "Installing ElasticSearch into #{elasticsearch_path}"
            FileUtils.mkdir_p @elasticsearch_path
            %w(bin config lib).each do |dir|
              unless File.exists? File.join(@elasticsearch_path, dir)
                FileUtils.cp_r File.join(ELASTICSEARCH_PATH, dir), File.join(@elasticsearch_path, dir)
              end
            end
          end
          @pid_dir = File.join ::Rails.root, "tmp", "pids"
          unless File.exists? config_dir
            FileUtils.mkdir_p config_dir
          end
          @log_dir = File.join ::Rails.root, "log"
          @data_dir = File.join elasticsearch_path, "data"
          FileUtils.mkdir_p data_dir unless File.exists? data_dir
          unless File.exists? config_path
            File.open(config_path, 'w') do |file|
              file << "path.logs: #{log_dir}\n"
              file << "path.data: #{data_dir}\n"
            end
          end
          @bootstrapped = true
        end
      end

      def bootstrapped?
        @bootstrapped || false
      end

      def elasticsearch_path
        @elasticsearch_path || ELASTICSEARCH_PATH
      end

      private

      def ensure_java_installed
        unless defined?(@java_installed)
          @java_installed = ElasticSearchable::Server::Java.installed?
          unless @java_installed
            raise JavaMissing.new("You need a Java Runtime Environment to run the ElasticSearch server")
          end
        end
        @java_installed
      end
    end
  end
end
