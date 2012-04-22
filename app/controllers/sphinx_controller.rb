# -*- coding: utf-8 -*-
class SphinxController < ApplicationController
  unloadable

  def show
    project = Project.find( params[:project_id] )
    projectId = params[:project_id].to_s
    revision = params[:revision].to_s
    repository = project.repository

    #compile sphinx document
    Sphinx.compile( projectId, revision, repository )
    #find document
    documentPathAtServer = Sphinx.search_redirect_path( projectId, revision, request )

    if documentPathAtServer 
      #redirect to sphinx document
      redirect_to documentPathAtServer
    end
  end

  #initial page
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
  #get repository type
  def check_repository_type( scm )
    case scm
    when Redmine::Scm::Adapters::GitAdapter 
      repositoryType = "git"
    when Redmine::Scm::Adapters::SubversionAdapter
      repositoryType = "subversion"
    when Redmine::Scm::Adapters::MercurialAdapter
      repositoryType = "mercurial"
    end
  end
    
end
