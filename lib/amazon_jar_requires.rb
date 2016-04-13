require 'java'

#Requiring the jars with require_relative wasn't working properly,
#so we do it this way.
Dir.chdir(File.dirname(__FILE__)) do
  require '../aws-java-sdk-1.10.69/lib/aws-java-sdk-1.10.69.jar'
  Dir[File.join('../aws-java-sdk-1.10.69/third-party/**/*.jar')].each do |jar|
    require jar
  end
end