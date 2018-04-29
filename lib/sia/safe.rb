module Sia
  # Keep your files safe
  #
  class Safe

    include Sia::Configurable

    # Initialize a safe
    #
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
      @key = Digest::SHA2.digest("#{password}#{salt}")
      @password = password

      check_password if File.directory?(safe_dir)
    end

    # The directory where this safe is stored
    #
    # @return [String]
    #
    def safe_dir
      File.join(options[:root_dir], @name.to_s)
    end

    # The absolute path to the public index file
    #
    # @return [String]
    #
    def index_path
      File.join(safe_dir, options[:index_name]).freeze
    end

    # An index of publicly available information about the safe
    #
    # @return [Hash] The safes' names, salts, and which files they contain.
    #
    def index
      File.exist?(index_path) ? YAML.load_file(index_path) : {}
    end

    # The absolute path to the secret file, storing the salt and password digest
    def secret_path
      File.join(safe_dir, options[:secret_name]).freeze
    end

    def secrets
      return unless File.exist?(secret_path)
      File.read(secret_path).split(':')
    end

    # A 64-bit salt encoded in binary
    def salt
      [
        secrets ? secrets[0] : @salt ||= SecureRandom.hex(64)
      ].pack('H*').freeze
    end

    # Secure a file in the safe
    #
    # @param [String] filename Relative or absolute path to file to secure.
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

      File.delete(filename)
    end

    # Extract a file from the safe
    #
    # @param [String] filename Relative or absolute path to file to extract.
    #   Note: This is the path to the file as it existed before being closed.
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

    def password_digest
      return @password_digest if defined? @password_digest
      iter = options[:digest_iterations]
      digest = OpenSSL::Digest::SHA512.new
      len = digest.digest_length
      @password_digest =
        Base64.urlsafe_encode64(
          OpenSSL::PKCS5.pbkdf2_hmac(@password, salt, iter, len, digest),
          padding: false
        )
    end

    # Used by Sia::Configurable
    #
    def defaults
      Sia.options.dup
    end

    def persist_safe_dir
      return if @safe_dir_persisted
      FileUtils.mkdir_p(safe_dir) unless File.directory?(safe_dir)
      if @salt
        File.write(secret_path, [@salt, password_digest].join(':'))
        remove_instance_variable(:@salt)
      end
      @safe_dir_persisted = true
    end

    def files
      index.fetch(:files, {}).freeze
    end

    # Prevent timing attacks
    # @see http://ruby-doc.org/stdlib-2.0.0/libdoc/openssl/rdoc/OpenSSL/PKCS5.html#module-OpenSSL::PKCS5-label-Important+Note+on+Checking+Passwords
    #
    def eql_time_cmp(a, b)
      return false unless a.length == b.length

      cmp = b.bytes.to_a
      result = 0
      a.bytes.each_with_index { |c, i| result |= c ^ cmp[i] }
      result == 0
    end

    def check_password
      return if eql_time_cmp(secrets[1], password_digest)
      raise Sia::PasswordError, 'Invalid password'
    end

    def update_index(k, v)
      yaml = index.merge(k => v).to_yaml
      File.write(index_path, yaml)
    end

    # Generate a urlsafe filename for storage in the safe
    def digest_filename(filename)
      digest = Digest::SHA2.digest(filename)
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
          w << cipher.update(r.read(options[:buffer_bytes])) until r.eof?
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
              w << decipher.update(r.read(options[:buffer_bytes]))
            end
          end
        end

        w << decipher.final
      end
    end

  end # class Safe
end # module Sia
