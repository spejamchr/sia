require 'yaml'
require 'securerandom'
require 'openssl'
require 'base64'

require 'sia/version'
require 'sia/error'
require 'sia/configurable'
require 'sia/persisted_config'

# Encrypt files with digital safes
#
module Sia

  class << self

    include Configurable

    # Configure Sia, returning the final options
    #
    #     Sia.config(
    #       root_dir: '/path/to/the/safes/',
    #       index_name: 'my_index',
    #       buffer_bytes: 2048,
    #     )
    #     # => {:root_dir=>"/path/to/the/safes/", :index_name=>"my_index", ...}
    #
    # Allows partial or piecemeal configuration.
    #
    #     Sia.options
    #     # => {:root_dir=>"~/.sia_safes"", :index_name=>".sia_index", ...}
    #
    #     Sia.config(root_dir: '/new_dir')
    #     # => {:root_dir=>"/new_dir", :index_name=>".sia_index", ...}
    #
    #     Sia.config(index_name: 'my_index')
    #     # => {:root_dir=>"/new_dir", :index_name=>"my_index", ...}
    #
    # See {Sia::Configurable::DEFAULTS} for all available options.
    #
    # @see Configurable::DEFAULTS
    #
    # @param [Hash] opt
    # @return [Hash]
    #
    def config(**opt)
      @options.merge!(clean_options(opt))
      options
    end

    # Persist the current Sia-wide options
    #
    # The next time Sia is loaded it will use the current config values.
    # Consequently, all new safes will use the current configuration as
    # defaults.
    #
    def persist!
      PersistedConfig.new.persist(options)
    end

    # Reset the options to default and return the options
    #
    #     Sia.config(root_dir: '/hi', index_name: 'there')
    #     # => {:root_dir=>'/hi', :index_name=>'there', ...}
    #     Sia.set_default_options!
    #     # => {:root_dir=>"~/.sia_safes", :index_name=>".sia_index", ...}
    #
    # With arguments, resets only the option(s) provided
    #
    #     Sia.config(root_dir: '/hi', index_name: 'there')
    #     # => {:root_dir=>'/hi', :index_name=>'there', ...}
    #     Sia.set_default_options!(:index_name)
    #     # => {:root_dir=>'/hi', :index_name=>".sia_index", ...}
    #
    # Optionally takes a `:source` keyword argument that determines whether the
    # default values should be taken from the gem or from the persisted config.
    # Values should be either `:persisted` or `:gem`. Default is `:persisted`.
    # If there is no persisted config the gem defaults are used.
    #
    # @note This change is not persisted.
    #
    # @param [Array<Symbol>] specifics Optionally reset only specific options
    # @param [:persisted|:gem] source Load defaults from gem or persisted config
    #
    # @return [Hash] The new options
    #
    def set_default_options!(*specifics, source: :persisted)
      specifics = DEFAULTS.keys if specifics.empty?
      keepers = (@options || {}).slice(*DEFAULTS.keys - specifics)
      @options = defaults(source).merge(keepers)
      options
    end

    private

    # Used by Sia::Configurable
    #
    # @param [:persisted|:gem] source Load defaults from gem or persisted config
    #
    def defaults(source=:persisted)
      case source
      when :persisted
        PersistedConfig.new.options
      when :gem
        DEFAULTS
      else
        raise "Unrecognized source: #{source.inspect}, must be :source or :gem"
      end
    end
  end # class << self
end

require 'sia/lock'
require 'sia/safe'
