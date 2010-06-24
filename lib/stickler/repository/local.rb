require 'stickler/spec_lite'
require 'stickler/repository'
require 'stickler/repository/api'
require 'rubygems/source_index'
require 'rubygems/format'
require 'rubygems/platform'
require 'rubygems/dependency'
require 'addressable/uri'

module Stickler::Repository
  #
  # A local repository of gems.  It implements the Repository::Api
  # and stores all the gems and specifications local to a root directory.
  #
  # It currently has two subdirectories:
  #
  # gems/           -> holding the .gem files 
  # specifications/ -> holding the .gemspec files
  #
  #
  class Local
    class Error < ::Stickler::Repository::Error; end

    # the root directory of the repository
    attr_reader :root_dir

    # the directory containing the .gem files
    attr_reader :gems_dir
   
    # the directory containing the .gemspec files
    attr_reader :specifications_dir

    def initialize( root_dir )
      @root_dir = File.expand_path( root_dir ) + File::SEPARATOR
      @gems_dir = File.join( @root_dir, 'gems/' )
      @specifications_dir = File.join( @root_dir, 'specifications/' )
      @source_index = Gem::SourceIndex.new
      setup_dirs
    end

    #
    # See Api#uri
    #
    def uri
      @uri ||= Addressable::URI.convert_path( root_dir )
    end

    # 
    # See Api#gems_uri
    #
    def gems_uri
      @gems_uri ||= Addressable::URI.convert_path( gems_dir )
    end

    #
    # See Api#specifications_uri
    #
    def specifications_uri
      @specficiations_uri ||= Addressable::URI.convert_path( specifications_dir )
    end

    #
    # See Api#source_index
    #
    def source_index
      @source_index.load_gems_in( specifications_dir )
      return @source_index
    end

    #
    # See Api#search_for
    #
    def search_for( spec )
      platform = Gem::Platform.new( spec.platform )
      dep      = Gem::Dependency.new( spec.name, spec.version )
      specs    = source_index.search( dep )
      specs    = specs.find_all { |spec| spec.platform == platform }
      return specs
    end

    #
    # See Api#add
    #
    def add( opts = {} )
      spec  = Stickler::SpecLite.new( opts[:name], opts[:version], opts[:platform] )
      specs = search_for( spec )
      raise Error, "gem #{spec.full_name} already exists" unless specs.empty?
      return install( spec, opts[:body] )
    end

    #
    # See Api#push
    #
    def push( path )
      spec = specification_from_gem_file( path )
      opts = { :name => spec.name, :version => spec.version.to_s, :platform => spec.platform }
      result = nil
      File.open( path ) do |io|
        result = add( opts.merge( :body => io ) )
      end
      return result
    end


    private

    def setup_dirs
      [ root_dir, specifications_dir, gems_dir ].each do |dir|
        FileUtils.mkdir_p( dir ) unless File.directory?( dir )
      end
    end

    def full_path_to_gem( spec )
      File.join( gems_dir, spec.file_name )
    end

    def full_path_to_specification( spec )
      File.join( specifications_dir, spec.spec_file_name )
    end


    def install( spec, io )
      install_gem( spec, io )
      install_specification( spec )
    end

    def install_gem( spec, io )
      File.open( full_path_to_gem( spec ) , "w+" ) do |of|
        io.each do |str|
          of.write( str )
        end
      end
    end

    def install_specification( spec )
      gemspec = specification_from_gem_file( full_path_to_gem( spec ) )
      File.open( full_path_to_specification( spec ) , "w+" ) do |f|
        f.write( gemspec.to_ruby )
      end
      return speclite_from_specification( gemspec )
    end

    def specification_from_gem_file( path )
      format = Gem::Format.from_file_by_path( path )
      return format.spec
    end

    def speclite_from_specification( spec )
      Stickler::SpecLite.new( spec.name, spec.version.to_s, spec.platform )
    end
  end
end
