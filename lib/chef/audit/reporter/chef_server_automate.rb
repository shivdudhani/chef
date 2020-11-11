require_relative 'automate'

class Chef
  module Audit
    module Reporter
      #
      # Used to send inspec reports to Chef Automate server via Chef Server
      #
      class ChefServerAutomate < Chef::Audit::Reporter::Automate
        def initialize(opts)
          @entity_uuid           = opts[:entity_uuid]
          @run_id                = opts[:run_id]
          @node_name             = opts[:node_info][:node]
          @insecure              = opts[:insecure]
          @environment           = opts[:node_info][:environment]
          @roles                 = opts[:node_info][:roles]
          @recipes               = opts[:node_info][:recipes]
          @url                   = opts[:url]
          @chef_tags             = opts[:node_info][:chef_tags]
          @policy_group          = opts[:node_info][:policy_group]
          @policy_name           = opts[:node_info][:policy_name]
          @source_fqdn           = opts[:node_info][:source_fqdn]
          @organization_name     = opts[:node_info][:organization_name]
          @ipaddress             = opts[:node_info][:ipaddress]
          @fqdn                  = opts[:node_info][:fqdn]
          @control_results_limit = opts[:control_results_limit]
          @timestamp             = opts.fetch(:timestamp) { Time.now }
        end

        def send_report(report)
          unless @entity_uuid && @run_id
            Chef::Log.error "entity_uuid(#{@entity_uuid}) or run_id(#{@run_id}) can't be nil, not sending report to Chef Automate"
            return false
          end

          automate_report = truncate_controls_results(enriched_report(report), @control_results_limit)

          report_size = automate_report.to_json.bytesize
          # this is set to slightly less than the oc_erchef limit
          if report_size > 900 * 1024
            Chef::Log.warn "Compliance report size is #{(report_size / (1024 * 1024.0)).round(2)} MB."
            Chef::Log.warn 'Infra Server < 13.0 defaults to a limit of ~1MB, 13.0+ defaults to a limit of ~2MB.'
          end

          Chef::Log.info "Report to Chef Automate via Chef Server: #{@url}"
          with_http_rescue do
            http_client.post(@url, automate_report)
            return true
          end
          false
        end

        def http_client
          config = if @insecure
            Chef::Config.merge(ssl_verify_mode: :verify_none)
          else
            Chef::Config
          end

          Chef::ServerAPI.new(@url, config)
        end

        def with_http_rescue
          response = yield
          if response.respond_to?(:code)
            # handle non 200 error codes, they are not raised as Net::HTTPClientException
            handle_http_error_code(response.code) if response.code.to_i >= 300
          end
          response
        rescue Net::HTTPClientException => e
          Chef::Log.error e
          handle_http_error_code(e.response.code)
        end

        def handle_http_error_code(code)
          case code
          when /401|403/
            Chef::Log.error 'Auth issue: see audit cookbook TROUBLESHOOTING.md'
          when /404/
            Chef::Log.error 'Object does not exist on remote server.'
          when /413/
            Chef::Log.error 'You most likely hit the erchef request size in Chef Server that defaults to ~2MB. To increase this limit see audit cookbook TROUBLESHOOTING.md OR https://docs.chef.io/config_rb_server.html'
          when /429/
            Chef::Log.error "This error typically means the data sent was larger than Automate's limit (4 MB). Run InSpec locally to identify any controls producing large diffs."
          end
          msg = "Received HTTP error #{code}"
          Chef::Log.error msg
          raise msg if @raise_if_unreachable
        end
      end
    end
  end
end
