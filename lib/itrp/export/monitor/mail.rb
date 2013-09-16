module Itrp
  module Export
    module Monitor
      class Mail
        def initialize(mail)
          @mail = mail
        end

        def original
          @mail
        end

        # value of mail header: X-ITRP-ExportID, e.g. 2
        def export_id
          @export_id ||= @mail.header['X-ITRP-ExportID'].try(:value).try(:to_i)
        end

        # value of mail header: X-ITRP-Export, e.g. '0fad4fc0fd4a0130ad2a12313b0e50759969ab71899d2bb1d3e3d8f66e6e5133'
        def token
          @token ||= @mail.header['X-ITRP-Export'].try(:value)
        end

        # First hyperlink in the text, e.g. https://itrp.amazonaws.com/exports/20130911/wdc/20130911-195545-affected_slas.csv?AWSAccessKeyId=AKIA&Signature=du%2B23ZUsrLng%3D&Expires=1379102146
        def download_uri
          return nil unless self.export_id
          # the first match from https:// until a space or the end of the line
          @download_uri ||= @mail.text_part.body.decoded[/(https?:\/\/[^\s$]+)/, 1]
        end

        # the filename of the csv or zip file
        def filename
          return nil if self.download_uri.blank?
          @filename ||= self.download_uri[/\/([^\/]+\.(?:csv|zip))\?/, 1]
        end

        # ignore the message
        def ignore
          @mail.skip_deletion
        end
      end
    end
  end
end