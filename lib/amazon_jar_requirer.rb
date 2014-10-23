require 'java'

require_relative '../aws-java-sdk-1.8.0/lib/aws-java-sdk-1.8.0.jar'
Dir[File.join('../aws-java-sdk-1.8.0/third-party/**/*.jar')].each do |jar|
  require_relative jar
end