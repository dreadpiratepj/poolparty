require "rubygems"
require "json"
require "#{::File.dirname(__FILE__)}/../../vendor/gems/dslify/lib/dslify"
require "#{::File.dirname(__FILE__)}/poolparty/default"
require "#{::File.dirname(__FILE__)}/schema"
require "#{::File.dirname(__FILE__)}/net/init"

module PoolParty
  def self.load_cloud_from_json(json_file_path=nil)
    json_file = json_file_path || PoolParty::Default.properties_hash_file
    PoolParty::Schema.new( ::File.read(json_file) )
  end
  
  def self.constantize(name, base_object=PoolParty)
    begin
      const = base_object.constants.find{|cnst| cnst == name.camel_case}
      base_object.module_eval const
    rescue Exception => e
      puts "#{name.camel_case} is not defined. #{e}"
      nil
    end
  end
end

class String
  def camel_case
    gsub(/(^|_|-)(.)/) { $2.upcase }
  end
end