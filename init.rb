# -*- coding: utf-8 -*-
require 'redmine'

Redmine::Plugin.register :redmine_sphinx do
  name 'Redmine Sphinx plugin'
  author 'nishio'
  description 'This is a plugin for Redmine'
  version '0.0.1'

  # top menuに追加  
  #  menu :top_menu, :sphinx_list, { :controller => 'sphinx', :action => 'index' }, :caption => "List", :last => true

  # sphinx用のメニュー追加
  permission :sphinx, {:sphinx => [:index]}, :public => true
  menu :project_menu, :sphinx_list, { :controller => 'sphinx', :action => 'index' }, :caption => 'Sphinxドキュメント', :param => :project_id
end
