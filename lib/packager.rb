#this class is responsible for bagging and tarring a given source directory, with some other
#convenience functions. All of the paths/files passed in should be absolute. The date may be
#a Date, a string representing a date, or nil
require 'date'
require 'pathname'
require 'bagit'

class Packager < Object

  attr_accessor :source_directory, :bag_directory, :date, :tar_file

  def initialize(args = {})
    self.source_directory = Pathname.new(args[:source_directory])
    self.bag_directory = Pathname.new(args[:bag_directory])
    self.tar_file = Pathname.new(args[:tar_file])
    self.date = self.set_date(args[:date])
  end

  def set_date(date_spec)
    if date_spec.is_a?(Date)
      self.date = date_spec
    elsif date_spec.is_a?(String)
      self.date = Date.parse(date_spec)
    else
      self.date = nil
    end
  end

  def make_tar
    if self.date
      self.make_incremental_tar
    else
      self.make_full_tar
    end
  end

  def make_full_tar
    making_bag_and_tar_with_data do
      bag_data_directory.rmtree if bag_data_directory.exist?
      bag_data_directory.make_symlink(source_directory)
    end
  end

  def make_incremental_tar
    making_bag_and_tar_with_data do
      bag_data_directory.mkpath
      link_modified_files(source_directory, bag_data_directory)
    end
  end

  #Link any files with mtime after the date in the source directory to the
  #target directory.
  #Create any directories in source_directory and apply recursively
  def link_modified_files(source_dir, target_dir)
    source_dir.each_child(true) do |child|
      child_target = target_dir.join(child.basename)
      if child.file? and (child.mtime >= self.date)
        child_target.symlink(child)
      elsif child.directory?
        child_target.mkpath
        link_modified_files(child, child_target)
      end
    end
  end

  def remove_bag_and_tar
    tar_file.unlink if tar_file.exist?
    bag_directory.rmtree if bag_directory.exist?
  end

  #Set up bag, run block to populate data, then manifest bag
  def making_bag_and_tar_with_data
    remove_bag_and_tar
    bag_directory.mkpath
    bag = BagIt::Bag.new(bag_directory)
    yield
    bag.manifest!
  end

  def bag_data_directory
    Pathname.new(File.join(bag_directory, 'data'))
  end

  def tar_command
    case RUBY_PLATFORM
      when /linux/
        'tar'
      when /darwin/
        #for darwin use homebrew (or other) GNU tar instead of BSD tar
        'gtar'
      else
        raise RuntimeError, 'Unrecognized platform'
    end
  end

end