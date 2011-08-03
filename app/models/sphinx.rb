# -*- coding: utf-8 -*-

class Sphinx 

  require 'shellwords'

  #redirect先を探す
  def self.search_redirect_path( projectId, revision, request )
    #sphinxおよびドキュメント配置サーバの設定
    sphinxSetting = SphinxPluginSettings.sphinx
    serverSetting = SphinxPluginSettings.server

    projectPath = serverSetting.document_root_path + serverSetting.sphinx_dir
    #sphinxのMakefileのパス取得
    sphinxPath = search_makefile( projectPath + "/" + projectId + "/" + revision, sphinxSetting.sphinx_makefile_head )
    #Makefileが存在するディレクトリ
    if sphinxPath
      sphinxPathDir = sphinxPath.gsub( /(Makefile$)/ , "")
    end

    #ドキュメントが見つかったかどうか
    if sphinxPathDir
      #Makefile内からbuild先のディレクトリ名を取得
      buildDirName = get_build_dir( sphinxPath )

      if buildDirName
        indexPath = sphinxPathDir + buildDirName + "/html/" + sphinxSetting.sphinx_index_page
      else
        sphinxDefaultBuildDir = "build/html/"
        indexPath = sphinxPathDir + sphinxDefaultBuildDir + sphinxSetting.sphinx_index_page
      end

      #sphinxのindex.htmlページを探してアドレスを取得
      exist = File.exists?(indexPath)
      if exist
        #server path
        serverIndexPath = indexPath.gsub(serverSetting.document_root_path, "")

        #server addressをリクエストから抜き出す
        serverAddress = request.headers['SERVER_NAME']
        serverPort = request.headers['SERVER_PORT']
        if serverSetting.server_port
          serverPort = serverSetting.server_port
        end

        #server path
        documentPathAtServer = "http://" + serverAddress.to_s + ":" + serverPort.to_s + "/" + serverIndexPath
      end
    end
    return documentPathAtServer
  end

  #sphinx documentのコンパイル
  def self.compile( projectId, revision, repository )
    #sphinxおよびドキュメント配置サーバの設定
    sphinxSetting = SphinxPluginSettings.sphinx
    serverSetting = SphinxPluginSettings.server

    #ドキュメントを設置する絶対パス
    projectPath = serverSetting.document_root_path + serverSetting.sphinx_dir;
    #repositoryの取得
    repositoryPath = repository.url
    #リポジトリにあわせてsphinx documentをコンパイル
    username = repository.login
    password = repository.password

    case repository.scm
    when Redmine::Scm::Adapters::GitAdapter 
      driver = GitDriver.new
    when Redmine::Scm::Adapters::SubversionAdapter
      driver = SubversionDriver.new
    when Redmine::Scm::Adapters::MercurialAdapter
      driver = MercurialDriver.new
    end

    if driver
      checkout_and_compile( driver, repositoryPath, projectPath, projectId, sphinxSetting.sphinx_makefile_head, revision, username, password )
    end
  end

  #sphinx makefileの場所を探す
  def self.search_makefile(path, sphinxMakefileHead)
    if FileTest.directory?( path ) 
      Dir.glob("#{path}/**/Makefile").each do |filepath|
        found = /^#{sphinxMakefileHead}/ =~ File.read(filepath) 
        if found
          return filepath
        end
      end
    end
    return nil
  end

  #sphinx makefile内からbuild先ディレクトリの情報を抜き出す
  def self.get_build_dir( path )
    /^\s*#{SphinxPluginSettings.sphinx.build_dir_variable_name}\s*=\s*(.*)$/s =~ File.read(path)
    return $1
  end

  #repositoryからsphinxドキュメントを取得してcompile
  def self.checkout_and_compile( driver, repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision, username, password )
    dirRevPath = "#{esc temporaryPath}/#{esc redmineProjectName}/#{esc revision}" 
    #既にコンパイル済みだったらいちいちmakeしない
    if File.exists?(dirRevPath)
      return
    end
    #repositoryからプロジェクトのチェックアウト
    driver.checkout( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision, username, password )
    #makeを行う
    doc = search_makefile( dirRevPath, sphinxMakefileHead )
    if doc
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd #{esc doc}; make html")
    end
  end

  private
  def self.esc(arg)
    Shellwords.shellescape(arg)
  end

end
