#This won't work as is, as I changed how the config works.
#This is really just to preserve this code until I've incorporated what I need into the real project
class OriginalTestCode
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