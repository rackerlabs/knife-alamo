require 'chef/knife'
require 'chef/knife/alamo_base'
require 'json'

class Chef
  class Knife
    class AlamoFlavorList < Knife
      banner "knife alamo flavor list"
      include Knife::AlamoBase
      def run
        nova_endpoint, auth_id = get_nova_endpoint
        flavors = JSON.parse RestClient.get "#{nova_endpoint}/flavors", {"X-Auth-Token" => auth_id, :content_type => :json, :accept => :json}

        items = {"id" => 1, "name" => 2,  "vcpus" => 1, "ram" => 1, "disk" => 1}

        entries = Array.new
        flavors["flavors"].each do |flavor|
          entry = JSON.parse RestClient.get "#{nova_endpoint}/flavors/#{flavor['id']}", {"X-Auth-Token" => auth_id, :content_type => :json, :accept=> :json}
          
          entries << entry["flavor"]
        end
        puts format(items, entries)
      end
    end
  end
end
