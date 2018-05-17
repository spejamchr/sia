module Sia
  # Keep all the files safe
  #
  # Encrypt files and store them in a digital safe. Have one safe for
  # everything, or use individual safes for each file to be encrypted.
  #
  # When creating a safe provide at least a name and a password, and the
  # defaults will take care of the rest.
  #
  #     safe = Sia::Safe.new(name: 'test', password: 'secret')
  #
  # With a safe in hand, {close} an existing file to keep it safe. (Note, any
  # type of file can be closed, not just `.txt` files.)
  #
  #     safe.close('~/secret.txt')
  #
  # The file will not longer be present at `/path/to/the/secret.txt`; instead,
  # it will now be encrypted in the default Sia directory with a new name.
  # Restore it by using {open}.
  #
  #     safe.open('~/secret.txt')
  #
  # Notice that {open} requires the path (relative or absolute) to the file as
  # it existed before being encrypted, even though there's no file at that
  # location anymore. To see all files available to open in the safe, take a
  # peak in the {index}.
  #
  #     pp safe.index
  #     {:files=>
  #       {"/Users/spencer/secret.txt"=>
  #         {:secure_file=>"0nxntvTLteCTZ8cmZdX848gGaYHRAOHqir-1RuJ-n-E",
  #          :last_closed=>2018-04-29 19:58:24 -0600,
  #          :safe=>true}}}
  #
  # The {fill} and {empty} methods are also helpful. {fill} will close all files
  # that belong to the safe, and {empty} will open all the files.
  #
  #     safe.fill
  #     safe.empty
  #
  # Finally, if the safe has outlived its usefulness, {delete} is there to help.
  # {delete} will remove a safe as-is, without opening or closing any files.
  # This means that **all currently closed files will be lost** when using
  # {delete}.
  #
  #     safe.delete
  #
  # FYI, the safe directory for this example has the structure:
  #
  #     ~/
  #     └── .sia_safes/
  #         └── test/
  #             ├── .sia_index
  #             ├── .sia_salt
  #             └── 0nxntvTLteCTZ8cmZdX848gGaYHRAOHqir-1RuJ-n-E
  #
  # The `.sia_safes/` directory holds all the safes, in this case the `test`
  # safe. Its name and location can be customized using {Configurable}. The
  # `test/` directory where the `test` safe lives. `.sia_index` is an encrypted
  # file that stores information about the safe. Its name cam be customized:
  # {Configurable}. The `.sia_salt` file stores the salt used to make a good
  # symmetric key out of the password. Its name cam be customized:
  # {Configurable}. The last file,
  # `0nxntvTLteCTZ8cmZdX848gGaYHRAOHqir-1RuJ-n-E`, is the newly encrypted file.
  # Its name is a `SHA256` digest of the full pathname of the clearfile (in this
  # case, `"/Users/spencer/secret.txt"`) encoded in url-safe base 64 without
  # padding (ie, not ending `'='`).
  #
  class Safe

    include Sia::Configurable

    attr_reader :name

    # @param [#to_sym] name
    # @param [#to_s] password
    # @param [Hash] opt Configure new safes as shown in {Configurable}.
    #   When instantiating existing safes, configuration here must match the
    #   persisted config, or be absent.
    # @return [Safe]
    #
    def initialize(name:, password:, **opt)
      @name = name.to_sym
      @persisted_config = PersistedConfig.new(@name)

      options # Initialize the options with defaults
      assign_options(opt)

      @lock = Lock.new(
        password.to_s,
        salt,
        options[:buffer_bytes],
        options[:digest_iterations]
      )

      # Don't let initialization succeed if the password was invalid
      index
    end

    # Persist the safe and its configuration
    #
    # This doesn't have any effect once a file has been closed in the safe.
    #
    def persist!
      return if @persisted_config.exist?

      safe_dir.mkpath unless safe_dir.directory?
      salt_path.write(salt) unless salt_path.file?

      @persisted_config.persist(options)

      update_index(:files, files)
    end

    # The directory where this safe is stored
    #
    # @return [Pathname]
    #
    def safe_dir
      options[:root_dir] / name.to_s
    end

    # The absolute path to the encrypted index file
    #
    # @return [Pathname]
    #
    def index_path
      safe_dir / options[:index_name]
    end

    # Information about the files in the safe
    #
    # @return [Hash]
    #
    def index
      return {} unless index_path.file?

      YAML.load(@lock.decrypt_from_file(index_path))
    rescue Psych::SyntaxError
      # A Psych::SyntaxError was raised in my integration test once when an
      # incorrect password was used. This raises the right error if that ever
      # happens again.
      raise Sia::Error::PasswordError, 'Invalid password'
    end

    # The absolute path to the file storing the salt
    #
    def salt_path
      safe_dir / options[:salt_name]
    end

    # The salt in binary encoding
    #
    def salt
      if salt_path.file?
        salt_path.read
      else
        @salt ||= SecureRandom.bytes(Sia::Lock::DIGEST.new.digest_length)
      end
    end

    # Secure a file in the safe
    #
    # @param [String] filename Relative or absolute path to file to secure.
    #
    def close(filename)
      clearpath = clear_filepath(filename)
      check_file_is_in_safe_dir(clearpath) if options[:portable]
      persist!

      @lock.encrypt(clearpath, secure_filepath(clearpath))

      info = files.fetch(clearpath, {}).merge(
        secure_file: secure_filepath(clearpath),
        last_closed: Time.now,
        safe: true
      )
      update_index(:files, files.merge(clearpath => info))
    end

    # Extract a file from the safe
    #
    # @param [String] filename Relative or absolute path to file to extract.
    #   Note: For in-place safes, the closed path may be used. Otherwise, this
    #   the path to the file as it existed before being closed.
    #
    def open(filename)
      clearpath = clear_filepath(filename)
      check_file_is_in_safe_dir(clearpath) if options[:portable]

      @lock.decrypt(clearpath, secure_filepath(clearpath))

      info = files.fetch(clearpath, {}).merge(
        secure_file: secure_filepath(clearpath),
        last_opened: Time.now,
        safe: false
      )
      update_index(:files, files.merge(clearpath => info))
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
    # All closed files are deleted. Open files are not deleted. The safe dir is
    # deleted if there is nothing besides closed files, the {#index_path}, and
    # the {#salt_path} in it.
    #
    def delete
      return unless @persisted_config.exist?

      files.each { |_, d| d[:secure_file].delete if d[:safe] }
      index_path.delete
      salt_path.delete
      safe_dir.delete if safe_dir.empty?

      @persisted_config.delete
    end

    private

    # Used by Sia::Configurable
    #
    def defaults
      @persisted_config.options.dup
    end

    def assign_options(opt)
      if @persisted_config.exist?
        news = options.merge(clean_options(opt))
        unless options == news
          differences = (news.to_a - options.to_a).map { |k, v|
            ":#{k} changed from `#{options[k]}` to `#{news[k]}`"
          }.join("\n  ")
          raise Sia::Error::ConfigurationError,
            "Cannot change safe configuration\n  #{differences}"
        end
      else
        @options.merge!(clean_options(opt))
      end
      @options.freeze
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
      digest = Digest::SHA256.digest(filename.to_s)
      filename = Base64.urlsafe_encode64(digest, padding: false)
    end

    def secure_filepath(filename)
      if options[:in_place]
        Pathname(filename.to_s + options[:extension])
      else
        safe_dir / digest_filename(filename)
      end
    end

    def clear_filepath(filename)
      filename = Pathname(filename).expand_path
      return filename unless options[:in_place]

      filename.extname == options[:extension] ? filename.sub_ext('') : filename
    end

    def check_file_is_in_safe_dir(filename)
      filename.ascend { |f| return if f == safe_dir }

      raise Sia::Error::FileOutsideScopeError, <<~MSG
        Portable safes can only open or close files within the `safe_dir`
          #{filename} is not a descendant of #{safe_dir}
      MSG
    end
  end # class Safe
end # module Sia
