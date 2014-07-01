require 'cattr'

class AmazonConfig

  cattr_accessor :aws_credentials, :config, :glacier_client, :sqs_client, :sns_client, :vault_name

  def self.initialize
    self.config = YAML.load_file('config/amazon.yaml')
    self.initialize_credentials
    self.initialize_clients
    self.vault_name = self.config['vault_name']
  end

  def self.initialize_credentials
    self.aws_credentials = BasicAWSCredentials.new(self.config['access_key_id'], self.config['secret_key'])
  end

  def self.initialize_clients
    self.glacier_client = AmazonGlacierClient.new(self.aws_credentials)
    self.glacier_client.set_endpoint(self.config['glacier_endpoint'])
    self.sqs_client = AmazonSQSClient.new(self.aws_credentials)
    self.sqs_client.set_endpoint(self.config['sqs_endpoint'])
    self.sns_client = AmazonSNSClient.new(self.aws_credentials)
    self.sns_client.set_endpoint(self.config['sns_endpoint'])
  end

end

AmazonConfig.initialize