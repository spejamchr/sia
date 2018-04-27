class Sia::Config
  def initialize
    @attributes = {}
  end

  def method_missing(method_name, *arguments, &block)
    if method_name.to_s[-1] = '='
      @attributes[method_name] = arguments.first
    else
      @attributes[method_name]
    end
  end

end
