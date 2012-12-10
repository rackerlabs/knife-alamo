require 'rest_client'
require 'json'
require 'digest/md5'
require 'chef/knife'
class Chef
  class Knife
    module AlamoBase
      Chef::Config[:knife][:alamo] = Hash.new

      def self.included(includer)
        includer.class_eval do
          deps do
            require 'net/ssh/multi'
            require 'readline'
            require 'chef/json_compat'
          end
          
          option :alamo_username,
          :short => "-A USERNAME",
          :long => "--openstack-usernamee USERNAME",
          :description => "Your openstack username",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:username] = entry.to_s }

          option :alamo_password,
          :short => "-P PASSWORD",
          :long => "--openstack-password PASSWORD",
          :description => "Your openstack password",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:password] = entry.to_s }

          option :alamo_auth_endpoint,
          :short => "-E ENDPOINT",
          :long => "--openstack-auth-endpoint URL",
          :description => "Your keystone endpoint",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:auth_url] = entry.to_s }

          option :alamo_tenant,
          :short => "-T TENANT",
          :long => "--openstack-tenant TENANT",
          :description => "Your tenant name",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:tenant] = entry.to_s }
        end
      end
      
      class KeystoneAuth
        attr_accessor :keystone_auth
        def initialize
          post_body = {
            "auth" =>
            {
              "passwordCredentials" =>
              {
                "username" => Chef::Config[:knife][:alamo][:username],
                "password" => Chef::Config[:knife][:alamo][:password]
              },
              "tenantName"=> Chef::Config[:knife][:alamo][:tenant]
            }
          }
          @keystone_auth = JSON.parse RestClient.post Chef::Config[:knife][:alamo][:auth_url], 
          post_body.to_json, :content_type => :json, :accept => :json
        end
      end

      def get_nova_endpoint
        auth = KeystoneAuth.new.keystone_auth
        auth_id = auth["access"]["token"]["id"]
        nova_endpoint = ""
        auth["access"]["serviceCatalog"].each do |endpoints|
          if endpoints["type"] == "compute"
            endpoints["endpoints"].each do | endpoint|
              nova_endpoint = endpoint["publicURL"] if endpoint["region"] == Chef::Config[:knife][:alamo][:region]
            end
          end
        end
        return nova_endpoint, auth_id
      end

      def format(keys, vals)
        retstr = ''
        keys.each{|(k,v)| retstr += k.ljust(8*v)}
        retstr += "\n"
        vals.each do |val|
          keys.each {|(k,v)| retstr += "#{val[k]}".ljust(8*v)}
          retstr += "\n"
        end
        retstr
      end
      def provision(server_id)
        begin
          bastion = Chef::Config[:knife][:alamo][:bastion]
          bastion_login = Chef::Config[:knife][:alamo][:bastion_login]
          bastion_pass = Chef::Config[:knife][:alamo][:bastion_pass]
          instance_login = Chef::Config[:knife][:alamo][:instance_login]
          privkey = Chef::Config[:knife][:alamo][:privkey_file] || nil
          runlist = Chef::Config[:knife][:alamo][:instance_runlist] || nil
          environment = Chef::Config[:knife][:alamo][:instance_chefenv] || nil
          nova_endpoint, auth_id = get_nova_endpoint

          server = JSON.parse RestClient.get "#{nova_endpoint}/servers/#{server_id}", {"X-Auth-Token" => auth_id, :content_type => :json, :accept => :json}
          until server['server']['status'] == 'ACTIVE'
            sleep(3)
            server = JSON.parse RestClient.get "#{nova_endpoint}/servers/#{server_id}", {"X-Auth-Token" => auth_id, :content_type => :json, :accept => :json}
          end

          server_ip = server['server']['addresses']['public'][0]['addr']
          
          gateway = Net::SSH::Gateway.new(bastion, bastion_login, :password => bastion_pass)
          
          # Use your regular old $HOME/.ssh/id_rsa if you don't specify one
          opt_block = privkey != nil ? {:keys => [privkey]} : {}
          gateway.ssh(server_ip, instance_login, opt_block) do |ssh|
            puts "Successfully logged in to instance. Firing up chef-client!"
            validation_key = IO.read(Chef::Config[:knife][:alamo][:validation_pem])
            
            clientrb = ["log_level :info",
                        "log_location STDOUT",
                        "ssl_verify_mode :verify_none",
                        "chef_server_url '#{Chef::Config[:chef_server_url]}'",
                        "validation_key '/etc/chef/validation.pem'",
                        "validation_client_name '#{Chef::Config[:validation_client_name]}'"].join("\n")
            
            command = "if [ `which chef-client | wc -l` -eq 0 ]; then "
            command << "if [ `whoami` != 'root' ]; then sudocmd='sudo '; else sudocmd=''; fi;"
            command << "curl -L https://www.opscode.com/chef/install.sh | $sudocmd bash && "
            command << "$sudocmd mkdir /etc/chef && "
            command << "echo \"#{clientrb}\" > client.rb && "
            command << "$sudocmd mv client.rb /etc/chef && "
            command << "echo \"#{validation_key}\" > validation.pem && "
            command << "$sudocmd mv validation.pem /etc/chef; "
            command << "fi; "
            
            opt_args = ""
            if runlist != nil
              opt_args << " -o #{runlist}"
            end
            if environment != nil
              opt_args << " -E #{environment}"
            end
            
            command << "$sudocmd chef-client #{opt_args}"
            
            ssh.exec(command)
          end
        rescue Exception => ex
          puts "Connection to instance failed: #{ex.message}"
          puts "Retrying connection..."
          sleep 1
          provision(server_id)
        end
      end
    end
  end
end


