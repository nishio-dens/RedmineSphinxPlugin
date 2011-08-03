# -*- coding: utf-8 -*-
class SphinxController < ApplicationController
  unloadable

  def show
    @project = Project.find( params[:project_id] )
    @projectId = params[:project_id].to_s
    @revision = params[:revision].to_s
    @repository = @project.repository

    #sphinx documentのコンパイル
    Sphinxs.compile_sphinx( @projectId, @revision, @repository )
    #documentを探す
    @documentPathAtServer = Sphinxs.search_redirect_path( @projectId, @revision, request )

    if @documentPathAtServer 
      #sphinx documentへのリダイレクト
      redirect_to @documentPathAtServer
    end
    @document = "sphinx documentが見つかりませんでした"
  end

  #初期ページ
  def index
    @project = Project.find( params[:project_id] )
    @projectId = params[:project_id]
    @repository = @project.repository
    if @repository 
      @changeset = @repository.changesets

      #repository type
      @repositoryType = check_repository_type( @repository.scm )
      if @repositoryType == "git" 
        @extrainfo = @repository.extra_info
      end
      @branches = @repository.branches
    end
  end

  private
  #repositoryのタイプ取得
  def check_repository_type( scm )
    case scm
    when Redmine::Scm::Adapters::GitAdapter 
      repositoryType = "git"
    when Redmine::Scm::Adapters::SubversionAdapter
      repositoryType = "subversion"
    when Redmine::Scm::Adapters::MercurialAdapter
      repositoryType = "mercurial"
    end
    return repositoryType
  end
    
end
