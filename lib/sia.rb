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

  end # class << self
end

require "sia/safe"
