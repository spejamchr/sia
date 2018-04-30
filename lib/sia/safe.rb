module Sia
  # Keep your files safe
  #
  class Safe

    include Sia::Configurable

    # @param [to_sym] name
    # @param [to_s] password
    # @param [Hash] opt Used to configure the safe
    # @return [Safe]
    #
    def initialize(name:, password:, **opt)
      validate_options(opt)
      @options.merge!(opt)
      @options.freeze

      @name = name.to_sym
      @lock = Lock.new(
        password.to_s,
        salt,
        options[:buffer_bytes],
        options[:digest_iterations]
      )

      # Don't let initialization succeed if the password was invalid
      index
    end

    # The directory where this safe is stored
    #
    # @return [String]
    #
    def safe_dir
      File.join(options[:root_dir], @name.to_s)
    end

    # The absolute path to the encrypted index file
    #
    # @return [String]
    #
    def index_path
      File.join(safe_dir, options[:index_name]).freeze
    end

    # Information about the files in the safe
    #
    # @return [Hash]
    #
    def index
      return {} unless File.exist?(index_path)

      YAML.load(@lock.decrypt_from_file(index_path))
    end

    # The absolute path to the file storing the salt
    #
    def salt_path
      File.join(safe_dir, options[:salt_name]).freeze
    end

    # The salt in binary encoding
    #
    def salt
      if File.exist?(salt_path)
        File.read(salt_path)
      else
        @salt ||= SecureRandom.bytes(Sia::Lock::DIGEST.new.digest_length)
      end
    end

    # Secure a file in the safe
    #
    # @param [String] filename Relative or absolute path to file to secure.
    #
    def close(filename)
      persist_safe_dir

      filename = File.expand_path(filename)

      info = files.fetch(filename, {}).merge(
        secure_file: digest_filename(filename),
        last_closed: Time.now,
        safe: true
      )
      update_index(:files, files.merge(filename => info))

      @lock.encrypt(filename, digest_filepath(filename))
    end

    # Extract a file from the safe
    #
    # @param [String] filename Relative or absolute path to file to extract.
    #   Note: This is the path to the file as it existed before being closed.
    #
    def open(filename)
      filename = File.expand_path(filename)

      info = files.fetch(filename, {}).merge(
        secure_file: digest_filename(filename),
        last_opened: Time.now,
        safe: false
      )
      update_index(:files, files.merge(filename => info))

      @lock.decrypt(filename, digest_filepath(filename))
    end

    # Open all files in the safe
    #
    def empty
      files.each { |filename, data| open(filename) if data[:safe]  }
    end

    # Close all files in the safe
    #
    def fill
      files.each { |filename, data| close(filename) unless data[:safe]  }
    end

    # Delete the safe as-is, without opening or closing files
    #
    # All closed files are lost. Open files are not lost.
    #
    def delete
      files.each do |filename, data|
        next unless data[:safe]
        File.delete(digest_filepath(filename))
      end
      FileUtils.rm_rf(safe_dir)
    end

    private

    # Used by Sia::Configurable
    #
    def defaults
      Sia.options.dup
    end

    def persist_safe_dir
      return if @safe_dir_persisted
      FileUtils.mkdir_p(safe_dir) unless File.directory?(safe_dir)
      File.write(salt_path, salt) unless File.exist?(salt_path)
      @safe_dir_persisted = true
    end

    def files
      index.fetch(:files, {}).freeze
    end

    def update_index(k, v)
      yaml = YAML.dump(index.merge(k => v))
      @lock.encrypt_to_file(yaml, index_path)
    end

    # Generate a urlsafe filename for storage in the safe
    def digest_filename(filename)
      digest = Digest::SHA2.digest(filename)
      filename = Base64.urlsafe_encode64(digest, padding: false)
    end

    def digest_filepath(filename)
      File.join(safe_dir, digest_filename(filename))
    end
  end # class Safe
end # module Sia
