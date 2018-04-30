require 'yaml'
require 'securerandom'
require 'openssl'
require 'base64'

require 'sia/info'
require 'sia/error'
require 'sia/configurable'

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
      validate_options(opt)
      @options.merge!(opt)
      options
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
    # @return [Hash]
    #
    def set_default_options!(*specifics)
      specifics = DEFAULTS.keys if specifics.empty?
      keepers = (@options || {}).slice(*DEFAULTS.keys - specifics)
      @options = defaults.merge(keepers)
      options
    end

    private

    # Used by Sia::Configurable
    #
    def defaults
      DEFAULTS.dup
    end

  end # class << self
end

require 'sia/lock'
require 'sia/safe'
