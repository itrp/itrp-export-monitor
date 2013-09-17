# ITRP Export Monitor


The itrp-export-monitor gem makes it easy to monitor a mailbox receiving [Scheduled Exports](http://help.itrp.com/help/export_fields) from ITRP and to store the incoming export files on disk or forward it to an FTP server.

This readme will take you through all the steps of setting up an export monitor:

* [Install Ruby, bundler and create a Gemfile](#installation)
* [Generate an export monitor](#generate-an-export-monitor)
* [Customize the configuration](#configuration)
* [Start the export monitor](#start-the-export-monitor)


Installation
------------

1. [Install Ruby 1.9.3 or higher](https://www.ruby-lang.org/en/downloads/)
2. Create a *root directory* for the ITRP Export Monitor and go to that directory, e.g.
   ```
   $ mkdir /usr/local/itrp_exports
   $ cd /usr/local/itrp_exports
   ```
3. Install [Bundler](http://bundler.io/)
   ```
   $ gem install bundler
   ```
4. Create a [`Gemfile`](http://bundler.io/v1.3/gemfile.html) in the *root directory* with the following contents:
   ```
   source 'https://rubygems.org'
   
   gem 'itrp-export-monitor'

   ```
5. Finally download the gems using bundler:
   ```
   $ bundle
   ```

Generate an Export Monitor
--------------------------

An export monitor is basically a ruby file that [configures](#configuration) the monitor and then fires it up to start looking for finished exports.

To help you create the ruby file, the following generator is available from the *root directory*:
```
$ itrp-export-monitor generate[<export ID>,<email address>,<imap password>]
```

The **export ID** is the unique identifier of the Scheduled Export in ITRP and can be found in the address bar of the browser when you view the Scheduled Export in ITRP at `https://<your domain>.itrp.com/exports`.

The **email address** is the email address where the export file is sent to. This is the email address of the user defined in the *Run as* field.

The **password** is the password with which the IMAP server can be accessed for this email address.

The default configuration is set up to work with [GMail](http://mail.google.com) and copies the downloaded export files to `/tmp/exports`.

Below is an example of the generated configuration:

```
$ cd /usr/local/itrp_exports
$ itrp-export-monitor generate[777,test.my.export@gmail.com,easy_to_gu3ss]
```

**/usr/local/itrp_exports/export_monitor.777.rb**

```
require 'itrp/export/monitor'

# the location where all the run-time information on the export monitor is stored
BASE_DIR = "/usr/local/itrp_exports/export_monitor_777"
FileUtils.mkpath "#{BASE_DIR}/log"

Itrp::Export::Monitor.configure do |export|
  export.root = BASE_DIR
  export.logger = Logger.new("#{BASE_DIR}/log/export_monitor.777.log")
  export.ids =    [777]

  export.to = '/tmp/exports'
  # export.to_ftp =        'ftp://...'
  # export.ftp_user_name = 'user'
  # export.ftp_password =  'secret'

  export.imap_address =    'imap.googlemail.com'
  export.imap_port =       993
  export.imap_user_name =  'test.my.export@gmail.com'
  export.imap_password =   'easy_to_gu3ss'
  export.imap_ssl =        true
  export.imap_mailbox =    'INBOX'
  export.imap_archive =    '[Gmail]/All Mail'
end

Itrp::Export::Monitor.run
```


Configuration
-------------

Before you [start the export monitor](#start-the-export-monitor) you need to customize the [generated configuration](#generate-an-export-monitor).

The Export Monitor configuration is defined using a block:
```
Itrp::Export::Monitor.configure do |export|
  export.root = '/usr/local/...'
  export.ids =    [777, 779]
  ...
end
```

All options available:

* _logger_:         The Ruby Logger instance, default: `Logger.new(STDOUT)`
* _daemonize_:      Set to `true` to run in daemon mode; not available on Windows (default: `false`)
* _root_:           **required** The root directory to store export monitor logs, pids and downloads
* _id/ids_:         **required** The id(s) of the scheduled exports to monitor
* _to_:             Location to store export files
* _to_ftp_:         The address of the FTP server to sent the completed downloads to
* _ftp_user_name_:  The user name to access the FTP server
* _ftp_password_:   The password to access the FTP server
* _imap_address_:   The address of the IMAP mail server (default: `imap.googlemail.com`)
* _imap_port_:      The port of the IMAP mail server (default: `993`)
* _imap_ssl_:       Set to +false+ to disabled SSL (default: `true`)
* _imap_user_name_: **required** The user name to access the IMAP server
* _imap_password_:  **required** The password to access the IMAP server
* _imap_mailbox_:   The mailbox to monitor for ITRP export mails (default: `INBOX`)
* _imap_archive_:   The archive mailbox to store the processed ITRP export mails (default: `[Gmail]/All Mail`)
* _on_exception_:   A Proc that takes an exception and the mail as an argument. By default exceptions will be logged as errors in the logfile.



Start the Export Monitor
------------------------

To start an export monitor simply run the following command:

```
$ cd /usr/local/itrp_exports
$ bundle exec ruby export_monitor.777.rb
```
