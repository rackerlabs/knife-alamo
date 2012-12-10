require 'chef/knife'
require 'chef/knife/alamo_base'
require 'json'

class Chef
  class Knife
    class AlamoAuth_lint < Knife
      include Knife::AlamoBase
      def run
        puts "Testing alamo auth with the following info:\n\tusername: %s\n\tpassword: %s [md5]\n\ttenant: %s\n\tauth endpoint: %s" %
          [Chef::Config[:knife][:alamo][:username],
           Digest::MD5.hexdigest(Chef::Config[:knife][:alamo][:password]),
           Chef::Config[:knife][:alamo][:tenant],
           Chef::Config[:knife][:alamo][:auth_url]]
        puts KeystoneAuth.new.keystone_auth
      end
    end
  end
end
