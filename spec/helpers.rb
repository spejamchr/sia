module Helpers
  def new_safe(name: 'test', password: 'abc')
    Sia::Safe.new(name, password)
  end
end
