require 'yaml'
require 'securerandom'
require 'openssl'
require 'base64'

require "sia/version"
require "sia/configurable"

module Sia

  class << self

    include Configurable

  end # class << self
end

require "sia/errors"
require "sia/safe"
