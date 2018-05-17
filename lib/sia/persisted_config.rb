module Sia
  # Sia-wide and safe-specific persisted config
  #
  # Sia can read and write Sia-wide persisted config, but can't read or write
  # any safe-specific config. Safes can read Sia-wide config, and can read and
  # write their own config, but can't access other safes' configs.
  #
  class PersistedConfig

    PATH = Pathname(Dir.home) / '.sia_config'

    # Provide a name for safe-specific access. Call w/o args for Sia-wide access
    #
    # @param [#to_sym|nil] name The name of the safe to be given access.
    #   Leave blank if Sia is to be given access.
    #
    def initialize(name=nil)
      @access_key = name ? :"safe #{name}" : :sia
    end

    # Persist some options into the persisted entry
    #
    # An attempt is made to not over-write things on accident by merging the
    # previously persisted options with Sia's defaults, and merging the provided
    # options into the result. This way, providing partial updates to the
    # options won't over-write all the other options, and if new options are
    # added to the gem later they will be effortlessly merged into the persisted
    # config without having to pass them explicitly.
    #
    # @param [Hash] opt The options to persist
    #
    def persist(opt)
      opt = Configurable::DEFAULTS.merge(options).merge(opt)

      whole_hash.merge!(@access_key => opt)

      PATH.write(YAML.dump(whole_hash))
    end

    # Load the persisted options from the persisted entry
    #
    def options
      entry = whole_hash.fetch(@access_key) do
        @access_key == :sia ? {} : Sia.options
      end

      Configurable::DEFAULTS.merge(entry)
    end

    def exist?
      whole_hash.has_key?(@access_key)
    end

    def delete
      return unless exist?

      whole_hash.delete(@access_key)

      PATH.write(YAML.dump(whole_hash))
    end

    def refresh
      @whole_hash = PATH.file? ? YAML.load(PATH.read) : {}
      nil
    end

    private

    # The entire persisted config hash, without access limitations
    #
    def whole_hash
      @whole_hash || refresh || @whole_hash
    end
  end
end
