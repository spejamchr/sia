module Sia
  # Keep your files safe
  #
  class Safe

    include Sia::Configurable

    # Initialize a safe
    #
    # @param [Hash] opt => requires :name and a :password keys
    #   Also accepts configuration keys.
    # @return [Safe]
    #
    def initialize(**opt, &block)
      validate_args(opt, required: [:name, :password])

      self.options = opt
      config(&block) if block_given?

      @name = opt[:name].to_sym
      @key = Digest::SHA2.digest("#{opt[:password]}#{salt}")

      check_password if File.directory?(safe_dir)
    end

    # The directory where this safe is stored
    #
    # @return [String]
    #
    def safe_dir
      File.join(options.root_dir, @name.to_s)
    end

    # The absolute path to the public index file.
    #
    # @return [String]
    #
    def index_path
      File.join(safe_dir, options.index_name).freeze
    end

    # An index of publicly available information about the safe
    #
    # @return [Hash] The safes' names, salts, and which files they contain.
    #
    def index
      File.exist?(index_path) ? YAML.load_file(index_path) : {}
    end

    # Secure a file in the safe
    #
    # @param [String] filename Relative or absolute path to file to secure
    #
    def close(filename)
      persist_safe_dir

      filename = File.expand_path(filename)

      _close(filename, digest_filepath(filename))

      info = files.fetch(filename, {}).merge(
        secure_file: digest_filename(filename),
        last_closed: Time.now,
        safe: true
      )
      update_index(:files, files.merge(filename => info))
      update_index(:salt, @salt) and @salt = nil unless @salt.nil?

      File.delete(filename)
    end

    # Extract a file from the safe
    #
    # @param [String] filename Relative or absolute path to file to extract
    #
    # Note: This is the path to the file as it existed before being closed.
    #
    def open(filename)
      filename = File.expand_path(filename)
      secure_file = digest_filepath(filename)

      _open(filename, secure_file)

      info = files.fetch(filename, {}).merge(
        secure_file: digest_filename(filename),
        last_opened: Time.now,
        safe: false
      )
      update_index(:files, files.merge(filename => info))

      File.delete(secure_file)
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

    def defaults
      Sia.options.dup
    end

    def validate_args(args, **opt)
      required = Hash[opt[:required].map { |a| [a, args[a]] }]
      missing = required.select { |k, v| !v || v.empty? }.keys
      return if missing.none?

      raise ArgumentError, "Missing required arg(s): #{missing.join(', ')}"
    end

    def persist_safe_dir
      return if @safe_dir_persisted
      FileUtils.mkdir_p(safe_dir) unless File.directory?(safe_dir)
      @safe_dir_persisted = true
    end

    def salt
      index.fetch(:salt) { @salt ||= SecureRandom.hex(16) }.freeze
    end

    def files
      index.fetch(:files, {}).freeze
    end

    def check_password
      files.each do |filename, data|
        next if digest_filename(filename) == data[:secure_file]
        raise Sia::PasswordError, 'Invalid password'
      end
    end

    def update_index(k, v)
      yaml = index.merge(k => v).to_yaml
      File.write(index_path, yaml)
    end

    # Generate a urlsafe filename for storage in the safe
    def digest_filename(filename)
      digest = Digest::SHA2.digest("#{@key}#{filename}")
      filename = Base64.urlsafe_encode64(digest, padding: false)
    end

    def digest_filepath(filename)
      File.join(safe_dir, digest_filename(filename))
    end

    def _close(clear_file, secure_file)
      File.open(clear_file, 'rb') do |r|
        File.open(secure_file, 'wb') do |w|
          cipher = OpenSSL::Cipher.new('AES-256-CBC')
          cipher.encrypt
          iv = cipher.random_iv
          cipher.key = @key
          cipher.iv  = iv

          w << iv
          w << cipher.update(r.read(options.buffer_bytes)) until r.eof?
          w << cipher.final
        end
      end
    end

    def _open(clear_file, secure_file)
      File.open(clear_file, 'wb') do |w|
        decipher = OpenSSL::Cipher.new('AES-256-CBC')
        decipher.decrypt
        decipher.key = @key

        first_block = true
        File.open(secure_file, 'rb') do |r|
          until r.eof?
            if first_block
              decipher.iv = r.read(decipher.iv_len)
              first_block = false
            else
              w << decipher.update(r.read(options.buffer_bytes))
            end
          end
        end

        w << decipher.final
      end
    end

  end # class Safe
end # module Sia
