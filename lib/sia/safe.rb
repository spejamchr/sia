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

    # @param [#to_sym] name
    # @param [#to_s] password
    # @param [Hash] opt Configure the safe as shown in {Configurable}.
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
      digest = Digest::SHA256.digest(filename)
      filename = Base64.urlsafe_encode64(digest, padding: false)
    end

    def digest_filepath(filename)
      File.join(safe_dir, digest_filename(filename))
    end
  end # class Safe
end # module Sia
