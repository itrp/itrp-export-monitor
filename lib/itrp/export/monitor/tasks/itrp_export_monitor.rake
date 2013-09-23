namespace :itrp_export_monitor do

  GENERATE_HELP = %(Generate a ruby file to configure and start the ITRP Export Monitor:\n  itrp-export-monitor generate[<export id>,<email address>,<IMAP password>])
  desc GENERATE_HELP
  task :generate, [:export_id, :email_address, :imap_password] do |t, args|
    check_required_args(args, [:export_id, :email_address, :imap_password], GENERATE_HELP)
    monitor_name = "export_monitor.#{args.export_id}"
    File.open("#{Dir.pwd}/#{monitor_name}.rb", 'w'){ |f| f.write(<<EOF) }
require 'itrp/export/monitor'

# the location where all the run-time information on the export monitor is stored
BASE_DIR = "#{Dir.pwd}/#{monitor_name.gsub('.', '_')}"
FileUtils.mkpath "\#{BASE_DIR}/log"

Itrp::Export::Monitor.configure do |export|
  export.root = BASE_DIR
  export.logger = Logger.new("\#{BASE_DIR}/log/#{monitor_name}.log")
  export.ids =    [#{args.export_id}]

  export.to = '/tmp/exports'
  # export.to_ftp =        'ftp.mycompany.com'
  # export.to_ftp_dir =    'my/exports'
  # export.ftp_user_name = 'user'
  # export.ftp_password =  'secret'

  export.imap_address =    'imap.googlemail.com'
  export.imap_port =       993
  export.imap_user_name =  '#{args.email_address}'
  export.imap_password =   '#{args.imap_password}'
  export.imap_ssl =        true
  export.imap_mailbox =    'INBOX'
  export.imap_archive =    '[Gmail]/All Mail'
end

Itrp::Export::Monitor.run
EOF
    $stdout.puts "\nGenerated '#{Dir.pwd}/#{monitor_name}.rb'."
    $stdout.puts "\nEdit the file and:"
    $stdout.puts " - fill in the IMAP details to connect to the mailbox that receives the ITRP Export mails"
    $stdout.puts " - specify the directory or FTP server to sent the export files to"
    $stdout.puts "\nStart the export monitor as follows:"
    $stdout.puts " $ bundle exec ruby #{monitor_name}.rb"
    $stdout.puts "\nFor more information and all available options look at the itrp-export-monitor gem documentation online.\n\n"
  end

  #desc %(List all scheduled exports:\n  itrp-export-monitor list['<api-token>'])
  #task :list, [:api_token] do |t, args|
  #  check_required_args(args, [:api_token])
  #  $stdout.puts "Searching for scheduled exports..."
  #  Itrp::Client.new(api_token: args.api_token).each('/exports')
  #  $stdout.puts "Account #{args.name} created successfully. The login instructions for #{account.url} are mailed to #{args.primary_email}."
  #end

  # Helper methods

  # test if required arguments are provided
  def check_required_args(args, fields, help)
    missing = fields.select{|field| args.send(field) == nil || args.send(field) == '' }
    unless missing.empty?
      $stderr.puts "\n#{help}"
      $stderr.puts "\nMissing required arguments: #{missing.join(', ')}"
      exit(1)
    end
  end
end