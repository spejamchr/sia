module Helpers
  def new_safe(name: 'test', password: 'abc', **opt, &block)
    args = opt.merge(name: name, password: password)
    block_given? ? Sia::Safe.new(args, &block) : Sia::Safe.new(args)
  end
end
