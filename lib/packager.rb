#this class is responsible for bagging and tarring a given source directory, with some other
#convenience functions. All of the paths/files passed in should be absolute. The date may be
#a Date, a string representing a date, or nil
require 'date'
require 'pathname'
require 'bagit'
require 'os'
require 'leveldb'

class Packager < Object

  attr_accessor :source_directory, :bag_directory, :date, :time, :tar_file, :logger, :old_manifests

  MANIFEST_FILE = 'manifest-md5.txt'
  INITIAL_MANIFEST_FILE = 'initial-manifest-md5.txt'
  MANIFEST_DB_DIR = '/tmp/glacier-manifest-db'

  def initialize(args = {})
    self.source_directory = Pathname.new(args[:source_directory])
    self.bag_directory = Pathname.new(args[:bag_directory])
    self.tar_file = Pathname.new(args[:tar_file])
    self.date = self.set_date(args[:date])
    self.logger = args[:logger]
    self.old_manifests = args[:old_manifests]
  end

  def set_date(date_spec)
    if date_spec.is_a?(Date)
      self.date = date_spec
    elsif date_spec.is_a?(String)
      self.date = Date.parse(date_spec)
    else
      self.date = nil
    end
    self.time = self.date.to_time if self.date
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
    logger.info('Removing old bag and tar if present')
    remove_bag_and_tar
    logger.info('Making new bag - incremental')
    bag_directory.mkpath
    bag = BagIt::Bag.new(bag_directory)
    bag_data_directory.mkpath
    link_modified_files(source_directory, bag_data_directory)
    Dir.chdir(bag_directory) do
      logger.info('Creating manifest with find')
      if system("#{find_command} -L data -type f -exec md5sum {} + > initial-manifest-md5.txt")
        logger.info 'Manifest created'
      else
        logger.info 'Error creating manifest'
      end
    end
    trim_manifest_and_data
    FileUtils.rm(INITIAL_MANIFEST_FILE)
    logger.info('Tarring bag')
    Dir.chdir(bag_directory.dirname) do
      system(tar_command, '--create', '--dereference', '--file', tar_file.to_s, bag_directory.basename.to_s)
    end
  end

  #an attempt at a non-recursive version of link_modified_files, which for very large
  #trees may be exhausting the heap
  def link_modified_files(starting_source_dir, starting_target_dir)
    queue = [[starting_source_dir, starting_target_dir]]
    while dirs = queue.pop
      source_dir, target_dir = dirs
      source_dir.each_child(true) do |child|
        child_target = target_dir.join(child.basename)
        if child.file? and ((child.mtime >= self.time) or (child.ctime >= self.time))
          child_target.make_symlink(child)
        elsif child.directory?
          child_target.mkpath
          queue.push([child, child_target])
        end
      end
    end
  end


  def trim_manifest_and_data
    if old_manifests.empty?
      FileUtils.cp(INITIAL_MANIFEST_FILE, MANIFEST_FILE)
    else
      with_manifest_db do |db|
        old_manifests.sort.each do |manifest|
          File.open(manifest).each_line do |line|
            line.chomp!
            md5sum, path = line.split(/\s+/, 2)
            db.put(path, md5sum)
          end
        end
      end
      File.open(MANIFEST_FILE, 'wb') do |manifest|
        File.open(INITIAL_MANIFEST_FILE) do |initial_manifest|
          initial_manifest.each_line do |line|
            line.chomp!
            md5sum, path = line.split(/\s+/, 2)
            if db.get(path) == md5sum
              delete_path = Pathname.new(File.join(bag_directory, path))
              delete_path.delete
              while delete_path = delete_path.parent
                break unless delete_path.children.empty?
                delete_path.delete
              end
            else
              manifest.puts(line)
            end
          end
        end
      end
    end
  end

  def remove_bag_and_tar
    tar_file.unlink if tar_file.exist?
    bag_directory.rmtree if bag_directory.exist?
  end

  #Set up bag, run block to populate data, then manifest bag
  def making_bag_and_tar_with_data
    logger.info('Removing old bag and tar if present')
    remove_bag_and_tar
    logger.info('Making new bag')
    bag_directory.mkpath
    bag = BagIt::Bag.new(bag_directory)
    yield
    Dir.chdir(bag_directory) do
      logger.info('Creating manifest with find')
      if system("#{find_command} -L data -type f -exec md5sum {} + > manifest-md5.txt")
        logger.info 'Manifest created'
      else
        logger.info 'Error creating manifest'
      end
    end
    logger.info('Tarring bag')
    Dir.chdir(bag_directory.dirname) do
      system(tar_command, '--create', '--dereference', '--file', tar_file.to_s, bag_directory.basename.to_s)
    end
  end

  def bag_data_directory
    Pathname.new(File.join(bag_directory, 'data'))
  end

  def tar_command
    if OS.linux?
      'tar'
    elsif OS.mac?
      #for darwin use homebrew (or other) GNU tar instead of BSD tar
      'gtar'
    else
      raise RuntimeError, 'Unrecognized platform'
    end
  end

  def find_command
    if OS.linux?
      'find'
    elsif OS.mac?
      'gfind'
    else
      raise RuntimeError, 'Unrecognized platform'
    end
  end

  def with_manifest_db
    yield LevelDb.open(MANIFEST_DB_DIR)
  ensure
    FileUtils.rm_rf(MANIFEST_DB_DIR) if Dir.exist?(MANIFEST_DB_DIR)
  end

end
