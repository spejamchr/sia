# Sia and individual safes can both be configured using this
#
module Sia::Configurable

  DEFAULTS = {
    root_dir: File.join(Dir.home, '.sia_safes').freeze,
    index_name: 'index'.freeze,
    buffer_bytes: 512,
  }.freeze

  # Reset the options to default and return the options.
  #
  # @return [Hash]
  #
  def set_default_options!
    @options = defaults
  end

  # The configuration options
  #
  # @return [Hash]
  #
  def options
    @options || set_default_options!
  end

  # Configure your safes with a hash. Returns the options.
  #
  #     Sia.options = {
  #       root_dir: '/path/to/your/safes/'
  #       index_name: 'my_index.txt'
  #       buffer_bytes: 2048
  #     }
  #
  # Allows partial or piecemeal configuration.
  #
  #     Sia.options
  #     # => {:root_dir=>".../.sia_safes", :index_name=>"index", ...}
  #
  #     Sia.options = { root_dir: '/new_dir' }
  #     Sia.options
  #     # => {:root_dir=>"/new_dir", :index_name=>"index", ...}
  #
  #     Sia.options = { index_name: 'my_index' }
  #     Sia.options
  #     # => {:root_dir=>"/new_dir", :index_name=>"my_index", ...}
  #
  # @param [Hash] opt
  # @return [Hash]
  #
  def options=(opt)
    validate(opt)
    options.merge!(opt)
  end

  private

  def validate(opt)
    unless opt.is_a? Hash
      raise Sia::ConfigurationError, "Expected Hash but got #{opt.class}"
    end

    illegals = opt.keys - defaults.keys
    unless illegals.empty?
      raise Sia::InvalidOptionError.new(illegals, defaults.keys)
    end
  end

  def defaults
    DEFAULTS.dup
  end

end
