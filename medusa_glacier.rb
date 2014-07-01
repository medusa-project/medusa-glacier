#!/usr/bin/env ruby
require 'java'
require 'yaml'
require_relative 'aws-java-sdk-1.8.0/lib/aws-java-sdk-1.8.0.jar'
Dir[File.join('aws-java-sdk-1.8.0/third-party/**/*.jar')].each do |jar|
  require_relative jar
end

import com.amazonaws.auth.AWSCredentials
import com.amazonaws.auth.BasicAWSCredentials
import com.amazonaws.services.glacier.AmazonGlacierClient
import com.amazonaws.services.glacier.transfer.ArchiveTransferManager
import com.amazonaws.services.glacier.transfer.UploadResult
import com.amazonaws.services.sns.AmazonSNSClient
import com.amazonaws.services.sqs.AmazonSQSClient
import com.amazonaws.services.glacier.model.DeleteArchiveRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsResult
import com.amazonaws.services.glacier.model.AbortMultipartUploadRequest

class MedusaGlacier

  attr_accessor :aws_credentials, :config, :glacier_client, :sqs_client, :sns_client, :archive_id, :vault_name

  def initialize
    self.config = YAML.load_file('config/rootkey.yaml')
    self.initialize_credentials
    self.initialize_clients
    if File.exists?('archive-id')
      self.archive_id = File.read('archive-id')
    else
      self.archive_id = nil
    end
    self.vault_name = self.config['vault_name']
  end

  def initialize_credentials
    self.aws_credentials = BasicAWSCredentials.new(self.config['access_key_id'], self.config['secret_key'])
  end

  def initialize_clients
    self.glacier_client = AmazonGlacierClient.new(self.aws_credentials)
    self.glacier_client.set_endpoint(self.config['glacier_endpoint'])
    self.sqs_client = AmazonSQSClient.new(self.aws_credentials)
    self.sqs_client.set_endpoint(self.config['sqs_endpoint'])
    self.sns_client = AmazonSNSClient.new(self.aws_credentials)
    self.sns_client.set_endpoint(self.config['sns_endpoint'])
  end

  def upload
    transfer_manager = ArchiveTransferManager.new(self.glacier_client, self.aws_credentials)
    result = transfer_manager.upload(self.vault_name, "Archive: #{Date.today}", java.io.File.new('sample.txt'))
    puts "Archive ID: #{result.getArchiveId()}"
    File.open('archive-id', 'w') {|f| f.puts result.getArchiveId}
  end

  def download
    raise "No Archive ID" unless self.archive_id
    transfer_manager = ArchiveTransferManager.new(self.glacier_client, self.sqs_client, self.sns_client)
    transfer_manager.download(self.vault_name, self.archive_id, java.io.File.new('return.txt'))
  end

  def delete
    delete_request = DeleteArchiveRequest.new()
    delete_request.withVaultName(self.vault_name)
    delete_request.withArchiveId(self.archive_id)
    self.glacier_client.delete_archive(delete_request)
  end

  def abort_current_uploads
    request = ListMultipartUploadsRequest.new('-', self.vault_name)
    response = self.glacier_client.listMultipartUploads(request)
    response.getUploadsList.each do |upload_list_element|
      puts "Aborting: " + upload_list_element.getMultipartUploadId
      abort_request = AbortMultipartUploadRequest.new('-', self.vault_name, upload_list_element.getMultipartUploadId)
      self.glacier_client.abortMultipartUpload(abort_request)
    end
  end

end


