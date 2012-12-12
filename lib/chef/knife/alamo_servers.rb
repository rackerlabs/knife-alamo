require 'chef/knife'
require 'chef/knife/alamo_base'
require 'json'
require 'net/ssh'
require 'net/ssh/multi'

class Chef
  class Knife
    class AlamoServerList < Knife
      banner "knife alamo server list"
      include Knife::AlamoBase
      def run
        nova_endpoint, auth_id = get_nova_endpoint
        servers = JSON.parse RestClient.get "#{nova_endpoint}/servers", {"X-Auth-Token" => auth_id, :content_type => :json, :accept => :json}
        items = {"id" => 5, "name" => 3, "status" => 2, "addresses" => 4}
        
        entries = Array.new
        servers["servers"].each do |server|
          entry = JSON.parse RestClient.get "#{nova_endpoint}/servers/#{server['id']}", {"X-Auth-Token" => auth_id, :content_type => :json, :accept=> :json}
          entries << entry['server']
        end
        
        puts format(items, entries)
      end
    end
    class AlamoServerCreate < Knife
      banner "knife alamo server create"
      include Knife::AlamoBase

      option :alamo_server_name,
      :long => "--name NAME",
      :description => "Assign server name",
      :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:server_name] = entry.to_s }
      
      option :alamo_image_ref,
      :long => "--image IMAGE_ID",
      :description => "Image ID to build server from",
      :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:image_ref] = entry.to_s }
      
      option :alamo_flavor_ref,
      :long => "--flavor FLAVOR_ID",
      :description => "Flavor ID to build server from",
      :proc => Proc.new { |entry| Chef::Config[:knife][:alamo][:flavor_ref] = entry.to_s }

      def run
        nova_endpoint, auth_id = get_nova_endpoint
        post_body = {
          "server" => {
            "name" => Chef::Config[:knife][:alamo][:server_name],
            "imageRef" => Chef::Config[:knife][:alamo][:image_ref],
            "flavorRef" => Chef::Config[:knife][:alamo][:flavor_ref],
            "key_name" => Chef::Config[:knife][:alamo][:key_name]
          }
        }
        server_record = JSON.parse RestClient.post "#{nova_endpoint}/servers", post_body.to_json, {"X-Auth-Token" => auth_id, :content_type => :json, :accept => :json}
        provision(server_record['server']['id'])
      end
    end

    class AlamoServerDelete < Knife
      banner "knife alamo server delete SERVER_ID"
      include Knife::AlamoBase
      def run
        unless name_args.size == 1
          puts "Please provide a id of a server to delete"
          show_usage
          exit 1
        end
        name_args.first
        nova_endpoint, auth_id = get_nova_endpoint
        RestClient.delete "#{nova_endpoint}/servers/#{name_args.first}", {"X-Auth-Token" => auth_id, :content_type => :json, :accept=> :json}
      end
    end

    class AlamoServerChefclient < Knife
      banner "knife alamo server chefclient SERVER_ID"
      include Knife::AlamoBase
      def run
        unless name_args.size == 1
          puts "Please provide a server id to provision with Chef"
          show_usage
          exit 1
        end
        provision(name_args.first)
      end
    end
  end
end

