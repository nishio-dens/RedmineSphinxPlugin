# -*- coding: utf-8 -*-
require 'redmine'

Redmine::Plugin.register :redmine_sphinx do
  name 'Redmine Sphinx plugin'
  author 'nishio'
  description 'This is a plugin for Redmine'
  version '0.0.1'

  # Add sphinx document tab
  permission :sphinx, {:sphinx => [:index]}, :public => true
  menu :project_menu, :sphinx_list, { :controller => 'sphinx', :action => 'index' }, :caption => 'Sphinx Documents', :param => :project_id
end
