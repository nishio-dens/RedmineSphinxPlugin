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
  def self.compile_sphinx( projectId, revision, repository )
    #sphinxおよびドキュメント配置サーバの設定
    sphinxSetting = SphinxPluginSettings.sphinx
    serverSetting = SphinxPluginSettings.server

    #ドキュメントを設置する絶対パス
    projectPath = serverSetting.document_root_path + serverSetting.sphinx_dir;
    #repositoryの取得
    repositoryPath = repository.url
    #リポジトリにあわせてsphinx documentをコンパイル
    case repository.scm
    when Redmine::Scm::Adapters::GitAdapter 
      compile_git_sphinx( repositoryPath, projectPath, projectId, sphinxSetting.sphinx_makefile_head, revision )
    when Redmine::Scm::Adapters::SubversionAdapter
      username = repository.login
      password = repository.password
      compile_subversion_sphinx( repositoryPath, projectPath, projectId, sphinxSetting.sphinx_makefile_head, revision, username, password )
    when Redmine::Scm::Adapters::MercurialAdapter
      compile_mercurial_sphinx( repositoryPath, projectPath, projectId, sphinxSetting.sphinx_makefile_head, revision )
    end
  end

  #sphinx makefileの場所を探す
  def self.search_makefile(path, sphinxMakefileHead)
    if FileTest.directory?( path ) 
      Dir.glob( "#{path}/**/Makefile" ).each do |filepath|
        makefile = File.open( filepath )
        #先頭文字列読み出し                                                                                                                
        headdata = makefile.gets
        makefile.close

        if headdata.start_with?( sphinxMakefileHead)
          sphinxMakefilePath = filepath #filepath.gsub( /(Makefile$)/ , "")
          #puts "#{filepath}".gsub( /(Makefile$)/ , "")
          #TODO: 複数のsphinx makefileがあった場合はどうする?
          return sphinxMakefilePath
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
  #argument:
  #  gitRepositoryPath: git repositoryのおいてあるpath
  #  temporaryPath: 一時的にコンパイル済みsphinxデータをおいておくpath
  #  redmine: project名
  #  sphinxMakefileHead: sphinxのmakefileのheadにある文字列
  #  revision: revision名
  def self.compile_git_sphinx( gitRepositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision )
    #既にコンパイル済みだったらいちいちmakeしない
    dirPath = "#{Shellwords.shellescape(temporaryPath)}/#{Shellwords.shellescape(redmineProjectName)}/#{Shellwords.shellescape(revision)}" 
    
    if File.exists?(dirPath)
      return
    end

    #git cloneを行って、適当なディレクトリにデータを取得する
    gitCloneCommand = "git clone #{Shellwords.shellescape(gitRepositoryPath)} #{Shellwords.shellescape(temporaryPath)}/#{Shellwords.shellescape(redmineProjectName)}/head"

    system(gitCloneCommand)
    #puts "command :" + gitCloneCommand
    #git pullでデータ取得
    gitDir = "#{Shellwords.shellescape(temporaryPath)}/#{Shellwords.shellescape(redmineProjectName)}"
    moveToGitDirCommand = "cd #{Shellwords.shellescape(gitDir)}/head"
    gitPullCommand = "git --git-dir=.git pull"

    #git pullを行ってheadデータ取得
    system( moveToGitDirCommand + ";" + gitPullCommand )

    #git revision copyを行う
    copyCommand = "cp -rf #{Shellwords.shellescape(gitDir)}/head/ #{Shellwords.shellescape(gitDir)}/#{Shellwords.shellescape(revision)}"
    checkoutCommand = "cd #{Shellwords.shellescape(gitDir)}/#{Shellwords.shellescape(revision)}" + ";" + "git checkout #{Shellwords.shellescape(revision)}" 
    system( copyCommand )
    system( checkoutCommand )

    doc = search_makefile( dirPath, sphinxMakefileHead )
    if doc
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd #{Shellwords.shellescape(doc)}; make html")
    end
  end

  #mercurialからsphinxドキュメントを取得してcompile
  def self.compile_mercurial_sphinx( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision )
    dirPath = "#{Shellwords.shellescape(temporaryPath)}/#{Shellwords.shellescape(redmineProjectName)}/#{Shellwords.shellescape(revision)}" 
    if File.exists?(dirPath)
      return
    end
    #projectを一時的においておくディレクトリ作成
    FileUtils.mkdir_p( dirPath ) 

    #適当なディレクトリにcloneを作る
    cloneCommand = "hg clone #{Shellwords.shellescape(repositoryPath)} " + dirPath
    system(cloneCommand)
    
    moveDirCommand = "cd " + dirPath 
    checkoutCommand = "hg checkout #{Shellwords.shellescape(revision)}"

    system( moveDirCommand + ";" + checkoutCommand )

    doc = search_makefile( dirPath, sphinxMakefileHead )
    if doc
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd #{Shellwords.shellescape(doc)}; make html")
    end
  end

  #repositoryからsphinxドキュメントを取得してcompile
  #argument:
  #  repositoryPath: git repositoryのおいてあるpath
  #  temporaryPath: コンパイル済みsphinxデータをおいておくpath
  #  redmine: project名
  #  sphinxMakefileHead: sphinxのmakefileのheadにある文字列
  #  revision: revision number
  #  username: subversion username
  #  password: subversion password
  def self.compile_subversion_sphinx( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision, username, password )
    #既にコンパイル済みだったらいちいちmakeしない
    dirPath = "#{Shellwords.shellescape(temporaryPath)}/#{Shellwords.shellescape(redmineProjectName)}/#{Shellwords.shellescape(revision)}" 
    if File.exists?(dirPath)
      return
    end
    #subversion checkout
    subversionCheckoutCommand = "svn checkout #{Shellwords.shellescape(repositoryPath)}@#{Shellwords.shellescape(revision)} "
    subversionCheckoutCommand = subversionCheckoutCommand + "--username #{Shellwords.shellescape(username)} --password #{Shellwords.shellescape(password)} " 
    subversionCheckoutCommand = subversionCheckoutCommand +  "#{Shellwords.shellescape(temporaryPath)}/#{Shellwords.shellescape(redmineProjectName)}/#{Shellwords.shellescape(revision)}"
    system(subversionCheckoutCommand) 

    doc = search_makefile(dirPath, sphinxMakefileHead)
    if doc
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd '#{Shellwords.shellescape(doc)}'; make html")
    end
  end
end
