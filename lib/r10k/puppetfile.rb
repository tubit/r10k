require 'r10k/module'
require 'r10k/logging'
require 'r10k/util/purgeable'
require 'r10k/util/path'

module R10K

# Provide the structure for Puppetfile data.
class Puppetfile

  include R10K::Logging

  # @!attribute [r] forge
  #   @return [String] The URL to use for the Puppet Forge
  attr_reader :forge

  # @!attribute [r] modules
  #   @return [Array<R10K::Module>]
  attr_reader :modules

  # @!attribute [r] basedir
  #   @return [String] The directory that contains the Puppetfile
  attr_reader :basedir

  # @!attribute [r] moduledir
  #   @return [String] The default directory to install the modules into.
  #     Defaults to `#{basedir}/modules`
  attr_reader :moduledir

  # @!attrbute [r] puppetfile_path
  #   @return [String] The path to the Puppetfile
  attr_reader :puppetfile_path

  # Generate a new Puppetfile instance.
  #
  # @param [String] basedir The directory that contains the default locations
  #   of the Puppetfile and moduledir
  # @return [String] moduledir The default directory to install the modules into.
  #   Defaults to `#{basedir}/modules`
  # @param [String] puppetfile The path to the Puppetfile. Defaults to
  #   `#{basedir}/Puppetfile`
  def initialize(basedir, moduledir = nil, puppetfile = nil)
    @basedir         = basedir
    @moduledir       = moduledir  || File.join(basedir, 'modules')
    @puppetfile_path = puppetfile || File.join(basedir, 'Puppetfile')

    @modules = []
    @forge   = 'forge.puppetlabs.com'
  end

  def load
    if File.readable? @puppetfile_path
      self.load!
    else
      logger.debug "Puppetfile #{@puppetfile_path.inspect} missing or unreadable"
    end
  end

  def load!
    dsl = R10K::Puppetfile::DSL.new(self)
    dsl.instance_eval(puppetfile_contents, @puppetfile_path)
  end

  # @param [String] forge
  def set_forge(forge)
    @forge = forge
  end


  # @param [String] moduledir
  def set_moduledir(moduledir)
    if R10K::Util::Path.is_relative?(moduledir)
      moduledir = File.join(@basedir, moduledir)
    end
    @moduledir = moduledir
  end

  # @param [String] name
  # @param [*Object] args
  def add_module(name, args)
    @modules << R10K::Module.new(name, @basedir, @moduledir, args)
  end

  include R10K::Util::Purgeable

  def managed_directory
    @moduledir
  end

  # List all modules that should exist in the module directory
  # @note This implements a required method for the Purgeable mixin
  # @return [Array<String>]
  def desired_contents
    @modules.map { |mod| mod.name }
  end

  private

  def puppetfile_contents
    File.read(@puppetfile_path)
  end

  # A barebones implementation of the Puppetfile DSL
  #
  # @api private
  class DSL

    def initialize(librarian)
      @librarian = librarian
    end

    def mod(name, args = [])
      @librarian.add_module(name, args)
    end

    def forge(location)
      @librarian.set_forge(location)
    end

    def moduledir(location)
      @librarian.set_moduledir(location)
    end

    def method_missing(method, *args)
      raise NoMethodError, "unrecognized declaration '#{method}'"
    end
  end
end
end
