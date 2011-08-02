# -*- coding: utf-8 -*-
require 'settingslogic'

class SphinxPluginSettings < Settingslogic
  source "#{Rails.root}/config/sphinx_plugin_setting.yml"
  namespace Rails.env

end

