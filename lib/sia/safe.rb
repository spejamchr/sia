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

    # Secure a file in the safe
    #
    # @param [String] filename Relative or absolute path to file to secure
    #
    def close(filename)
      persist_safe_dir

      filename = File.expand_path(filename)
      secure_file = digest_filepath(filename)

      _close(filename, secure_file)

      info = files.fetch(filename, {}).merge(
        secure_file: secure_file,
        last_closed: Time.now,
        safe: true
      )
      update_entry(:files, files.merge(filename => info))
      update_entry(:salt, @salt) and @salt = nil unless @salt.nil?

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
        secure_file: secure_file,
        last_opened: Time.now,
        safe: false
      )
      update_entry(:files, files.merge(filename => info))

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
        File.delete(data[:secure_file])
      end
      i = index
      yaml = i.slice(*(i.keys - [@name])).to_yaml
      File.write(index_path, yaml)
    end

    private

    def defaults
      Sia.options.dup
    end

    def validate_args(args, **opt)
      required = Hash[opt[:required].map { |a| [a, args[a]] }]
      return if required.values.all? { |v| v.is_a?(String) }

      missing = required.select { |k, v| !v || v.empty? }.keys

      raise ArgumentError, "Missing required arg(s): #{missing.join(', ')}"
    end

    def persist_safe_dir
      return if @safe_dir_persisted
      FileUtils.mkdir_p(safe_dir) unless File.directory?(safe_dir)
      @safe_dir_persisted = true
    end

    # Provide a copy of the entry file.
    def entry
      index.fetch(@name, {}).freeze
    end

    def salt
      entry.fetch(:salt) { @salt ||= SecureRandom.hex(16) }.freeze
    end

    def files
      entry.fetch(:files, {}).freeze
    end

    def check_password
      files.each do |filename, data|
        next if digest_filepath(filename) == data[:secure_file]
        raise Sia::PasswordError, 'Invalid password'
      end
    end

    def update_entry(k, v)
      yaml = index.merge(@name => entry.merge(k => v)).to_yaml
      File.write(index_path, yaml)
    end

    # Generate a urlsafe filename for storage in the safe
    def digest_filepath(filename)
      digest = Digest::SHA2.digest("#{@key}#{@name}#{filename}")
      filename = Base64.urlsafe_encode64(digest, padding: false)
      File.join(options[:safe_dir], filename)
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
          w << cipher.update(r.read(buffer_bytes)) until r.eof?
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
              w << decipher.update(r.read(buffer_bytes))
            end
          end
        end

        w << decipher.final
      end
    end

  end # class Safe
end # module Sia
