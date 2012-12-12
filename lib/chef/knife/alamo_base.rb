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
            require 'chef/json_compat'
          end
          
          option :alamo_openstack_user,
          :long => "--openstack-user USERNAME",
          :description => "Your openstack username",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:openstack_user] = entry.to_s }

          option :alamo_openstack_pass,
          :long => "--openstack-pass PASSWORD",
          :description => "Your openstack password",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:openstack_pass] = entry.to_s }

          option :alamo_controller_ip,
          :long => "--controller-ip IP",
          :description => "Your keystone endpoint",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:controller_ip] = entry.to_s }

          option :alamo_tenant,
          :long => "--openstack-tenant TENANT",
          :description => "Your tenant name",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:tenant] = entry.to_s }

          option :alamo_region,
          :long => "--openstack-region REGION",
          :description => "Your openstack region",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:region] = entry.to_s }
       
          option :alamo_key_name,
          :long => "--key-name KEYNAME",
          :description => "name of ssh key to be embedded into instances.",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:key_name] = entry.to_s }

          option :alamo_instance_ssh_user,
          :long => "--instance-ssh-user USER",
          :description => "The user to ssh into instances with",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:instance_ssh_user] = entry.to_s }

          option :alamo_instance_runlist,
          :long => "--runlist RUNLIST_ITEM1,RUNLIST_ITEM2,...",
          :description => "List of roles/recipes to initially run after chef-client installation.",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:instance_runlist] = entry.to_s }

          option :alamo_instance_chefenv,
          :long => "--chefenv CHEF_ENVIRONMENT",
          :description => "Chef environment to assign the instance to.",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:instance_chefenv] = entry.to_s }

          option :alamo_privkey_file,
          :long => "--privkey /PATH/TO/ID_RSA",
          :description => "ssh key (private) for the instance. Defaults to ssh's builtin locations if empty (~/.ssh/id_rsa)",
          :proc => Proc.new{ |entry| Chef::Config[:knife][:alamo][:privkey_file] = entry.to_s }

          option :alamo_validation_pemfile,
          :long => "--validation-pemfile /PATH/TO/VALIDATION.PEM",
          :description => "Chef validation.pem file. If unspecified, will snag it from the controller node.",
          :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:privkey_file] = entry.to_s }

        end
      end

      class KeystoneAuth
        attr_accessor :keystone_auth
        def self.gen_endpoint
          return "http://#{Chef::Config[:knife][:alamo][:controller_ip]}:5000/v2.0/tokens"
        end
        def initialize
          post_body = {
            "auth" =>
            {
              "passwordCredentials" =>
              {
                "username" => Chef::Config[:knife][:alamo][:openstack_user],
                "password" => Chef::Config[:knife][:alamo][:openstack_pass]
              },
              "tenantName"=> Chef::Config[:knife][:alamo][:openstack_tenant]
            }
          }
          @keystone_auth = JSON.parse RestClient.post KeystoneAuth::gen_endpoint, post_body.to_json, :content_type => :json, :accept => :json
        end
      end

      def get_nova_endpoint
        auth = KeystoneAuth.new.keystone_auth
        auth_id = auth["access"]["token"]["id"]
        nova_endpoint = ""
        auth["access"]["serviceCatalog"].each do |endpoints|
          if endpoints["type"] == "compute"
            endpoints["endpoints"].each do | endpoint|
              nova_endpoint = endpoint["publicURL"] if endpoint["region"] == Chef::Config[:knife][:alamo][:openstack_region]
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
          bastion = Chef::Config[:knife][:alamo][:controller_ip]
          bastion_login = Chef::Config[:knife][:alamo][:ssh_user]
          bastion_pass = Chef::Config[:knife][:alamo][:ssh_pass]
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
          if Chef::Config[:knife][:alamo][:validation_pem] != nil
            validation_key = IO.read(Chef::Config[:knife][:alamo][:validation_pem])
          end
          gateway.ssh(server_ip, instance_login, opt_block) do |ssh|
            puts "Successfully logged in to instance. Firing up chef-client!"

            
            clientrb = ["log_level :info",
                        "log_location STDOUT",
                        "ssl_verify_mode :verify_none",
                        "chef_server_url '#{Chef::Config[:chef_server_url]}'",
                        "validation_key '/etc/chef/validation.pem'",
                        "validation_client_name '#{Chef::Config[:validation_client_name]}'"].join("\n")
            
            command = "if [ `which chef-client | wc -l` -eq 0 ]; then "
            command << "echo Chef client not installed. Installing chef-client...; "
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


