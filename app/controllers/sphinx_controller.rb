# -*- coding: utf-8 -*-
class SphinxController < ApplicationController
  unloadable

  #sphinxドキュメント設置ディレクトリ
  @@sphinxDir = Settings.server.sphinx_dir
  #公開ディレクトリのルートパス
  @@documentRoot = Settings.server.document_root_path
  #sphinxのMakefileの先頭文字列
  @@sphinxMakefileHead = Settings.sphinx.sphinx_makefile_head
  #sphinxの初期ページ
  @@sphinxIndexPage = Settings.sphinx.sphinx_index_page
  #serverのアドレス
  @@serverPort = Settings.server.server_port
  
  def show
    @project = Project.find( params[:project_id] )
    @projectId = params[:project_id].to_s
    @revision = params[:revision].to_s
    @repository = @project.repository

    #sphinx documentのコンパイル
    Settings.compile_sphinx( @projectId, @revision, @repository )

    projectPath = @@documentRoot + @@sphinxDir
    #sphinxのMakefileのパス取得
    sphinxPath = Settings.search_makefile( projectPath + "/" + @projectId + "/" + @revision, @@sphinxMakefileHead )
    #Makefileが存在するディレクトリ
    if( sphinxPath != nil && sphinxPath != "" ) then
      sphinxPathDir = sphinxPath.gsub( /(Makefile$)/ , "")
    end

    @document = "Sphinx Document Not Found."
    #ドキュメントが見つかったかどうか
    found = false
    if sphinxPathDir then

      #Makefile内からbuild先のディレクトリ名を取得
      buildDirName = Settings.get_build_dir( sphinxPath )

      if ( buildDirName != nil && buildDirName != "" ) then
        indexPath = sphinxPathDir + buildDirName + "/html/" + @@sphinxIndexPage
      else
        sphinxDefaultBuildDir = "build/html/"
        indexPath = sphinxPathDir + sphinxDefaultBuildDir + @@sphinxIndexPage
      end

      #sphinxのindex.htmlページを探してアドレスを取得
      begin
        f = open( indexPath )
        @document = f.read
        f.close

        #server path
        serverIndexPath = indexPath.gsub( @@documentRoot, "" )

        #server addressをリクエストから抜き出す
        @serverAddress = request.headers['SERVER_NAME']
        @serverPort = request.headers['SERVER_PORT']
        if( @@serverPort != nil ) then
          @serverPort = @@serverPort
        end
        #server path
        @documentPathAtServer = "http://" + @serverAddress.to_s + ":" + @serverPort.to_s + "/" + serverIndexPath

        found = true
      rescue
        @document = "Found sphinx makefile buf Document not found. path: " + indexPath
      end
    end

    if( found ) then
      #sphinx documentへのリダイレクト
      redirect_to @documentPathAtServer
    end
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
        @branches = @repository.branches
      end
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
