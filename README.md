ITRP Export Monitor
-------------------

Usage:

* Install Ruby (version 1.9.3 or higher)
* Install RubyGems and Bundler
* Create a new directory for your monitors, e.g. `mkdir /usr/local/itrp/exports/`
* Create a filed called `Gemfile` with the following contents:
    ```
    source 'https://rubygems.org'

    gem 'itrp-export-monitor'
    ```
* Run `bundle` from the command line
* Run `itrp-export-monitor list --api_token 'ab3198ff3213ec...1dc9043823afbb321'
    ```
    3412 Weekly People Export (full)
    3477 Daily Request Export (incremental)
    ```
* Run `itrp-export-monitor monitor 3477 --api_token 'ab3198ff3213ec...1dc9043823afbb321'
