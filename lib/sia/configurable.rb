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
  # @return [Struct]
  #
  def set_default_options!
    @options = defaults
  end

  # The configuration options
  #
  # @return [Struct]
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
  # @param [Hash] opt
  # @return [Struct]
  #
  def options=(opt)
    unless opt.is_a? Hash
      raise ArgumentError, "Expected Hash but got #{opt.class}"
    end

    opt.each do |k, v|
      next unless DEFAULTS.keys.include? k.to_sym
      options.send("#{k}=", v)
    end
    options
  end

  # Configure your safes with a block. Returns the options.
  #
  #     Sia.config do |options|
  #       options.root_dir = '/path/to/your/safes/'
  #       options.index_name = 'my_index.txt'
  #       options.buffer_bytes = 2048
  #     end
  #
  # @return [Struct]
  #
  def config
    yield options
    options
  end

  private

  def defaults
    Struct.new(*DEFAULTS.keys).new(*DEFAULTS.values)
  end

end
