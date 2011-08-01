require 'settingslogic'

class Settings < Settingslogic
  source "#{Rails.root}/config/sphinx_plugin_setting.yml"
  namespace Rails.env
end
