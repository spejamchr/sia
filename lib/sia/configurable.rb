# Sia and individual safes can both be configured using this
#
module Sia::Configurable

  DEFAULTS = {
    root_dir: File.join(Dir.home, '.sia_safes').freeze,
    index_name: 'index'.freeze,
    buffer_bytes: 512,
  }.freeze

  # Define accessors for each option
  DEFAULTS.each do |opt, def_val|
    define_method(opt) { options[opt] }
    define_method("#{opt}=") { |val| self.options = { opt => val } }
  end
  alias_method :config_root_dir, :root_dir

  def set_default_options!
    @options = defaults
  end

  def options
    @options || set_default_options!
  end

  def options=(opt)
    options.merge!(opt.slice(*options.keys))
  end

  # Configure your safes
  #
  #     Sia.config do |s|
  #       s.root_dir = '/path/to/your/safes/'
  #       s.index_name = 'my_index.txt'
  #       s.buffer_bytes = 2048
  #     end
  #
  def config
    yield self
  end

  # The absolute path to the public index file.
  #
  def index_path
    File.join(config_root_dir, index_name).freeze
  end

  # An index of publicly available information about the safe
  # @return [Hash] The safes' names, salts, and which files they contain.
  #
  def index
    File.exist?(index_path) ? YAML.load_file(index_path) : {}
  end

  private

  def defaults
    DEFAULTS.dup
  end

end
