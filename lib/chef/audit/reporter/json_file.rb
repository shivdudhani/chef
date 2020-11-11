require_relative "../../json_compat"

class Chef
  module Audit
    module Reporter
      class JsonFile
        def initialize(opts)
          @path = opts.fetch(:file)
        end

        def send_report(report)
          File.write(@path, Chef::JSONCompat.to_json(report))
        end
      end
    end
  end
end
