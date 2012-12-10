require 'chef/knife'
require 'chef/knife/alamo_base'
require 'json'

class Chef
  class Knife
    class AlamoImageList < Knife
      banner "knife alamo image list"
      include Knife::AlamoBase
      def run
        nova_endpoint, auth_id = get_nova_endpoint
        images = JSON.parse RestClient.get "#{nova_endpoint}/images", {"X-Auth-Token" => auth_id, :content_type => :json, :accept => :json}

        items = {"id" => 5, "name" => 5, "minDisk" => 2, "minRam" => 2}

        entries = Array.new
        images["images"].each do |image|
          entry = JSON.parse RestClient.get "#{nova_endpoint}/images/#{image['id']}", {"X-Auth-Token" => auth_id, :content_type => :json, :accept=> :json}
          entries << entry['image']
        end

        puts format(items, entries)
      end
    end
  end
end
