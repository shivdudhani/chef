require "uri" unless defined?(URI)
require "plugins/inspec-compliance/lib/inspec-compliance"

class Chef
  module Audit
    module Fetcher
      class Automate < ::InspecPlugins::Compliance::Fetcher
        name "chef-automate"

        # it positions itself before `compliance` fetcher
        # only load it, if you want to use audit cookbook in Chef Solo with Chef Automate
        priority 502

        CONFIG = {
          "insecure" => true,
          "token" => nil,
          "server_type" => "automate",
          "automate" => {
            "ent" => "default",
            "token_type" => "dctoken",
          },
        }.freeze

        def self.resolve(target)
          uri = get_target_uri(target)
          return nil if uri.nil?

          config = CONFIG.dup

          # we have detailed information available in our lockfile, no need to ask the server
          if target.respond_to?(:key?) && target.key?(:url)
            profile_fetch_url = target[:url]
          else
            # verifies that the target e.g base/ssh exists
            base_path = "/compliance/profiles/#{uri.host}#{uri.path}"

            profile_path = if target.respond_to?(:key?) && target.key?(:version)
                             "#{base_path}/version/#{target[:version]}/tar"
                           else
                             "#{base_path}/tar"
                           end

            url = URI(Chef::Config[:data_collector][:server_url])
            url.path = profile_path
            profile_fetch_url = url.to_s

            config["token"] = Chef::Config[:data_collector][:token]

            if config["token"].nil?
              raise "No data-collector token set, which is required by the chef-automate fetcher. " \
                "Set the `data_collector.token` configuration parameter in your client.rb " \
                'or use the "chef-server-automate" reporter which does not require any ' \
                "data-collector settings and uses Chef Server to fetch profiles."
            end
          end

          new(profile_fetch_url, config)
        rescue URI::Error => _e
          nil
        end

        def to_s
          "Chef Automate for Chef Solo Fetcher"
        end
      end
    end
  end
end
