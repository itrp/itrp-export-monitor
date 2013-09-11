module Itrp
  module Export
    class Mail
      def initialize(mail)
        @mail = mail
      end

      # retrieve the ITRP Export ID from the mail
      def export_id
        #TODO: implement
      end

      # ignore the message
      def ignore
        @mail.skip_deletion
      end
    end
  end
end