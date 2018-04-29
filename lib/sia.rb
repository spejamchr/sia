require 'yaml'
require 'securerandom'
require 'openssl'
require 'base64'

require "sia/info"
require "sia/errors"
require "sia/configurable"

module Sia

  class << self

    include Configurable

    # Configure Sia, returning the final options
    #
    #     Sia.config(
    #       root_dir: '/path/to/your/safes/',
    #       index_name: 'my_index.txt',
    #       buffer_bytes: 2048,
    #     )
    #     # => {:root_dir=>"/path/to/your/safes/", ...}
    #
    # Allows partial or piecemeal configuration.
    #
    #     Sia.options
    #     # => {:root_dir=>"~/.sia_safes"", :index_name=>"index", ...}
    #
    #     Sia.config(root_dir: '/new_dir')
    #     # => {:root_dir=>"/new_dir", :index_name=>"index", ...}
    #
    #     Sia.config(index_name: 'my_index')
    #     # => {:root_dir=>"/new_dir", :index_name=>"my_index", ...}
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
    #     Sia.config(root_dir: 1, index_name: 2, buffer_bytes: 3)
    #     # => {:root_dir=>1, :index_name=>2, :buffer_bytes=>3}
    #     Sia.set_default_options!
    #     # => {:root_dir=>"~/.sia_safes", :index_name=>"index", ...}
    #
    # @return [Hash]
    #
    def set_default_options!
      @options = defaults
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

require "sia/safe"
