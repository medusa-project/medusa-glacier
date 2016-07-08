require 'java'
require 'fileutils'
require 'base64'
require 'date'

require_relative 'amazon_jar_requires'
require_relative 'amazon_config'
require_relative 'packager'
require 'simple_amqp_server'

import com.amazonaws.services.glacier.transfer.ArchiveTransferManager
import com.amazonaws.services.glacier.transfer.UploadResult
import com.amazonaws.services.glacier.model.DeleteArchiveRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsResult
import com.amazonaws.services.glacier.model.AbortMultipartUploadRequest
import com.amazonaws.event.ProgressTracker

class MedusaGlacierServer < SimpleAmqpServer::Base

  def initialize(args = {})
    super(args)
    AmazonConfig.initialize(config.amazon)
  end

  def cfs_root
    self.config.cfs(:cfs_root)
  end

  def bag_root
    self.config.cfs(:bag_root)
  end

  def handle_upload_directory_request(interaction)
    self.logger.info "Handling upload"
    relative_directory = interaction.request_parameter('directory')
    source_directory = File.join(self.cfs_root, relative_directory)
    unless File.directory?(source_directory)
      interaction.fail_generic('Upload directory not found')
      return
    end
    ingest_id = relative_directory.gsub('/', '-')
    packager = Packager.new(:source_directory => source_directory, :bag_directory => File.join(self.bag_root, ingest_id),
        :tar_file => File.join(self.bag_root, "#{ingest_id}.tar"), :date => interaction.request_parameter('date'))
    packager.make_tar
    archive_id = self.upload_tar(packager, interaction.request_parameter('description'))
    self.save_manifest(packager.bag_directory, ingest_id)
    self.logger.info "Removing tar and bag directory"
    packager.remove_bag_and_tar
    interaction.succeed(:archive_ids => [archive_id])
  end

  def upload_tar(packager, description = nil)
    #There are problems if the description has certain characters - it can only have ascii 0x20-0x7f by Amazon specification,
    #and it seems to have problems with ':' as well using this API, so we deal with it simply by base64 encoding it.
    encoded_description = Base64.strict_encode64(description || '')
    transfer_manager = ArchiveTransferManager.new(AmazonConfig.glacier_client, AmazonConfig.aws_credentials)
    progress_listener = ProgressTracker.new
    result = nil
    upload_thread = Thread.new do
      self.logger.info "Doing upload"
      self.logger.info "Vault: #{AmazonConfig.vault_name}"
      self.logger.info "Tarball: #{packager.tar_file} Bytes: #{packager.tar_file.size}"
      #It seems that when making the java file object we need to use the full path
      result = transfer_manager.upload("-", AmazonConfig.vault_name, encoded_description,
                                       java.io.File.new(packager.tar_file.to_s), progress_listener)
      self.logger.info "Archive uploaded with archive id: #{result.getArchiveId()}"
    end
    progress_thread = Thread.new do
      while true
        begin
          sleep 1800
          bytes_transferred = progress_listener.get_progress.get_request_bytes_transferred
          percentage_transferred = (100.0 * bytes_transferred) / packager.tar_file.size
          self.logger.info "Request bytes transferred: #{bytes_transferred} %: #{percentage_transferred.round(2)}"
        rescue Exception => e
          self.logger.info "Problem tracking progress: #{e}"
        end
      end
    end
    upload_thread.join
    progress_thread.kill
    return result.getArchiveId()
  end

  def save_manifest(bag_directory, ingest_id)
    FileUtils.mkdir_p(File.join(self.bag_root, 'manifests'))
    manifest_file = File.join(bag_directory, 'manifest-md5.txt')
    manifest_destination = File.join(self.bag_root, 'manifests', "#{ingest_id}-#{Date.today}.md5.txt")
    if File.exists?(manifest_file)
      FileUtils.copy(manifest_file, manifest_destination)
    else
      FileUtils.touch(manifest_destination)
    end
  end

  def handle_delete_archive_request(interaction)
    self.logger.info "Handling deletion"
    unless self.config.server(:allow_deletion)
      self.logger.info "Deletion not allowed by this server"
      interaction.fail_generic "Deletion not allowed by this server"
      return
    end
    archive_id = interaction.request_parameter('archive_id')
    unless archive_id
      self.logger.info "No archive id specified"
      interaction.fail_generic "No archive id specified"
      return
    end
    self.logger.info "Deleting archive: #{archive_id}"
    delete_archive(archive_id)
    interaction.succeed(:archive_id => archive_id)
  end

  #This isn't directly in the current workflow, It's a convenience for testing, etc.
  def delete_archive(archive_id)
    delete_request = DeleteArchiveRequest.new
    delete_request.with_vault_name(AmazonConfig.vault_name)
    delete_request.with_archive_id(archive_id)
    AmazonConfig.glacier_client.delete_archive(delete_request)
  end

end
