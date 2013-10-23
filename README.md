# ITRP Export Monitor


The itrp-export-monitor gem makes it easy to monitor a mailbox
receiving [Scheduled Exports](http://help.itrp.com/help/export_fields) from ITRP
and to store the incoming export files on disk or forward them to an FTP server.

This readme will take you through all the steps of setting up an Export Monitor:

* [Install Ruby, bundler and create a Gemfile](#installation)
* [Generate an Export Monitor](#generate-an-export-monitor)
* [Customize the configuration](#configuration)
* [Start the Export Monitor](#start-the-export-monitor)
* [Monitor the Export Monitor](#monitor-the-export-monitor)


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

An Export Monitor is basically a ruby file that [configures](#configuration) the monitor
and then fires it up to start looking for finished exports in the mailbox.

To help you create the ruby file, the following generator is available from the *root directory*:
```
$ itrp-export-monitor generate[<export ID>,<email address>,<imap password>]
```

The **export ID** is the unique identifier of the Scheduled Export in ITRP
and can be found in the address bar of the browser when you view
the Scheduled Export in ITRP at `https://<your domain>.itrp.com/exports`.

The **email address** is the email address where the export file is sent to.
This is the email address of the user defined in the *Run as* field.
**We strongly recommend to [create a separate mailbox](setup-a-mailbox) for the export monitor.**

The **password** is the password with which the IMAP server can be accessed for this email address.

The default configuration is set up to work with [GMail](http://mail.google.com) (in English)
and copies completed export files to `/tmp/exports`.

Below is an example of the generated configuration:

```
$ cd /usr/local/itrp_exports
$ itrp-export-monitor generate[777,test.my.export@gmail.com,easy_to_gu3ss]
```

**/usr/local/itrp_exports/export_monitor.777.rb**

```
require 'itrp/export/monitor'

# the location where all the run-time information on the Export Monitor is stored
BASE_DIR = "/usr/local/itrp_exports/export_monitor_777"
FileUtils.mkpath "#{BASE_DIR}/log"

Itrp::Export::Monitor.configure do |export|
  export.root =       BASE_DIR
  export.logger =     Logger.new("#{BASE_DIR}/log/export_monitor.777.log")
  export.ids =        [777]
  export.unzip =      true
  export.sub_dirs =   false

  export.to = '/tmp/exports'
  # export.to_ftp =        'ftp.mycompany.com'
  # export.to_ftp_dir =    'my/exports'
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

Before you [start the Export Monitor](#start-the-export-monitor)
you need to customize the [generated configuration](#generate-an-export-monitor).

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
* _exit_when_idle_: Number of minutes after which the service stops when no Export mails are found (default: `-1` no exit)
* _root_:           **required** The root directory to store Export Monitor logs, pids and downloads
* _id/ids_:         **required** The id(s) of the Scheduled Exports to monitor, e.g. `[777]`
* _unzip_:          Unzip the CSV files, default: `true`.
* _sub_dirs_:       Place each CSV file in a different subdirectory based on the export type (default: `false`)
* _to_:             Directory to store export files on local disk, e.g. `'/tmp/people_export'`
* _to_ftp_:         The address of the FTP server to sent the completed downloads to, e.g. `'ftp.mycompany.com'`
* _to_ftp_dir_:     The subdirectory on the FTP server, e.g. `'my/downloads'` (default: `'.'`)
* _ftp_user_name_:  The user name to access the FTP server
* _ftp_password_:   The password to access the FTP server
* _imap_address_:   **required** The address of the IMAP mail server (default: `'imap.googlemail.com'`)
* _imap_port_:      The port of the IMAP mail server (default: `993`)
* _imap_ssl_:       Set to +false+ to disabled SSL (default: `true`)
* _imap_user_name_: **required** The user name to access the IMAP server
* _imap_password_:  **required** The password to access the IMAP server
* _imap_mailbox_:   The mailbox to monitor for ITRP export mails (default: `'INBOX'`)
* _imap_archive_:   The archive mailbox to store the processed ITRP export mails (default: `'[Gmail]/All Mail'`)
* _on_exception_:   A Proc that takes an exception and the mail as an argument: `Proc.new{ |ex, mail| ... }`.
  All exceptions will also be logged as errors in the logfile.
* _csv_row_sep_:    Set the CSV row separator (default: `:auto`, i.e. windows/unix newline)
* _csv_col_sep_:    Set the CSV column separator (default: `','`)
* _csv_quote_char_: Set the CSV quote character, at most 1 character (default: `'"'`)
* _csv_value_proc_: Provide a procedure to change values before adding them to the CSV, e.g.
  `Proc.new{ |value| value.gsub(/\r?\n/, ' ')`


Start the Export Monitor
------------------------

To start an Export Monitor simply run the following command:

```
$ cd /usr/local/itrp_exports
$ bundle exec ruby export_monitor.777.rb
```

If the configuration is correct, the Export Monitor will startup and keep on running until it
receives a *QUIT* signal (by pressing `<ctrl>-C`).

If the Export Monitor stops running immediately the configuration is probably incorrect.
The log file will contain the details on what went wrong, see:
```
$ less /usr/local/itrp_exports/export_monitor_777/log/export_monitor.777.log
```

If the Export Monitor is running, but the exports are not picked up and processed as expected, also check
the log file first.

On startup the following directory structure will be created in the *export.root* directory:

```
/usr
  /local
    /itrp_exports
      /export_monitor_777
        /downloads
          ...
        /log
          export_monitor.777.log
        /pids
          export_monitor.777.pid
        /tmp
          clacks_config.export_monitor.777.rb
```

The `downloads` subdirectory contains the downloaded csv/zip files. These files are not
deleted automatically, so it is advisable to [monitor the disk usage](#disk-usage).

The `log` directory contains the log file of the Export Monitor.

The `pids` directory contains the pid file of the Export Monitor.

The `tmp` directory contains temporary files to run the Export Monitor and should be left alone.


Monitoring the Export Monitor
-----------------------------

The process ID of the Export Monitor will be stored in the `<root dir>/pids/export_monitor.<id>.pid` file.
Tools like [Monit](http://mmonit.com/monit/) can be used to make sure the Export Monitor is always running.

When an incoming export could not be processed correctly, an error is logged in the logfile
which is located in `<root dir>/log/export_monitor.<id>.log`. You should either watch this logfile for
errors, or define a custom *on_exception* handler to take the [appropriate action](#recovering-from-errors).

Below is an example of an *on_exception* handler sending a mail to a systems mailbox using
the [mail gem](https://github.com/mikel/mail).

```
Itrp::Export::Monitor.configure do |export|
  ...
  export.on_exception = Proc.new do |ex, mail|
    Mail.deliver do
      from    'export.monitor@mycompany.example.com'
      to      'sysadmin@mycompany.example.com'
      subject "Unable to process incoming export mail: #{mail.original.subject}"
      body    ex.message
    end
  end
end
```

#### Recovering from errors

When an export mail could not be processed correctly:

1. the error is logged in the logfile (once)
2. the *on_exception* handler is called (once)
3. the mail is left in the *imap_mailbox*

After that the mail will not be processed again unless the Export Monitor is restarted.

#### Disk usage

All export files that are downloaded are kept in the `<export.root>/downloads` directory.
These files are not deleted automatically, so you might want to add a job to cleanup this
directory every month/year depending on your setup.

#### No a real service?

The `exit_when_idle` option may be used to stop the Export Monitor when there are no new
export mails coming in for a couple of minutes. This may be useful in case you want to
fire up the Export Monitor at a scheduled time using the cron-tab or Windows Task Scheduler.

Other considerations
--------------------

#### Setup a mailbox

It is best to create a separate user in ITRP with a corresponding mailbox for each Export Monitor.

For example: if the Export Monitor will monitor the Weekly Full People, you could create a
[GMail](http://mail.google.com) for *people.monitor.mycompany@gmail.com*. Then create a new
[ITRP User](http://developer.itrp.com/v1/general/getting_started/) using that email address.

That's it. Now you are ready to [generate an Export Monitor](#generate-an-export-monitor).

#### Not a dedicated mailbox?

The Export Monitor will search all mails in the *imap_mailbox* for export mails sent by ITRP.
When an export mail is found and the export ID matches one of the *ids* in the
[configuration](#configuration), the mail is processed. Other mails in the same *imap_mailbox*
are left alone.

If there are a lot of mails kept in the mailbox the processing may slow down.
It is advisable to create a separate user in ITRP with the Account Administrator role and
it's own mailbox for processing exports.

That user should then be selected as the *Run as* user in the Scheduled Export.

#### IMAP

All options starting with the *imap* prefix are used to access the mailbox to monitor incoming mails.
By default the configuration is setup for [GMail](http://mail.google.com).

Contact the System Administrator of your mailbox in case you are not sure how to setup the IMAP
configuration.

#### Multiple Scheduled Exports

To monitor and process multiple Scheduled Exports simply provide all the export IDs to monitor
in the [configuration](#configuration):

```
export.ids = [777, 785, 786]
```

#### Forwarding export mails

Forwarded mails will not be processed as the Export Monitor depends on the ITRP
[mail message headers](http://developer.itrp.com/v1/export/#downloading-an-export-file) to be available in the mail.
When a mail is forwarded these headers may not be found and the export mail is not processed.

#### Export files that are partially copied

To prevent issues with partial files the export monitor will append `.in_progress` to export files
that are being copied/FTP'd. Once the copy is completed, the file is renamed and the `.in_progress` suffix
is removed.

Another way to prevent issues with partially copied files is to try to obtain a write lock on the file
before processing the export file. The OS will return an error when the file is not completely copied.

#### CSV not fully supported?

Some systems, like [SAP BI](http://scn.sap.com/thread/3200938), cannot handle well-defined CSV files.
As a workaround the Export Monitor can rewrite the CSV files in a different format. To do so, take a look
at the [configuration](#configuration).

The most common issue is that new-lines within a value are not handled correctly when the new-line is also used
as a row separator. One way to deal with that is to replace the new-lines in the values with a different value:

```
Itrp::Export::Monitor.configure do |export|
  export.csv_value_proc = Proc.new{ |value| value.gsub(/\r?\n/, ' ') }
end
```
