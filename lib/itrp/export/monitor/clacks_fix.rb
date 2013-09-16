# -*- encoding: binary -*-
module Clacks
  class Command

    def setup_signal_handling
      stop_signal = (Signal.list.keys & ['QUIT', 'INT']).first
      Signal.trap(stop_signal) do
        Clacks.logger.info 'QUIT signal received. Shutting down gracefully.'
        @service.stop if @service
      end unless stop_signal.nil?

      Signal.trap('USR1') do
        Clacks.logger.info 'USR1 signal received. Rotating logs.'
        rotate_logs
      end if Signal.list['USR1']
    end

  end
end