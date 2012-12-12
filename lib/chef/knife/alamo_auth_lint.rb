require 'chef/knife'
require 'chef/knife/alamo_base'
require 'json'

class Chef
  class Knife
    class AlamoAuth_lint < Knife
      include Knife::AlamoBase
      def run
        puts "Testing alamo auth with the following info:\n\tusername: %s\n\tpassword: %s [md5]\n\ttenant: %s\n\tauth endpoint: %s" %
          [Chef::Config[:knife][:alamo][:openstack_user],
           Digest::MD5.hexdigest(Chef::Config[:knife][:alamo][:openstack_pass]),
           Chef::Config[:knife][:alamo][:openstack_tenant],
           KeystoneAuth.gen_endpoint]
        puts KeystoneAuth.new.keystone_auth
      end
    end
  end
end
