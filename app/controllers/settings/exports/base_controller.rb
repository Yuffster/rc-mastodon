# frozen_string_literal: true

module Settings
  module Exports
    class BaseController < ApplicationController
      before_action :authenticate_user!

      def index
        @export = Export.new(current_account)

        respond_to do |format|
          format.csv { send_data export_data, filename: export_filename }
        end
      end

      private

      def export_filename
        "#{controller_name}.csv"
      end
    end
  end
end
