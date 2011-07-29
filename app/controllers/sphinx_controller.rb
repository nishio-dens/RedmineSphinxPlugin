# -*- coding: utf-8 -*-
class SphinxController < ApplicationController
  unloadable

  #一時的にgitのプロジェクトがおいてある場所を指定
  #TODO: ここの設定をどこから読み込むか(最後のslashはいる)
  @@tempDir = Settings.server.temp_dir
  @@projectPath = Settings.server.project_path
  #sphinxのMakefileの先頭文字列
  @@sphinxMakefileHead = Settings.sphinx.sphinx_makefile_head
  #sphinx Makefile内のbuildディレクトリを指定している変数名
  @@buildDirVariableName= Settings.sphinx.build_dir_variable_name
  #sphinxの初期ページ
  @@sphinxIndexPage = Settings.sphinx.sphinx_index_page
  #serverのアドレス
  @@serverPort = Settings.server.server_port
  
  def show
    @projectId = params[:project_id].to_s
    @revision = params[:revision].to_s

    #あとで別の場所に処理を移動させる
    projectPath = @@projectPath + @@tempDir

    #repositoryの情報取得
    @project = Project.find( params[:project_id] )
    #git repositoryの取得
    gitRepositoryPath = @project.repository.url

    #sphinx documentのコンパイル
    compileSphinx( gitRepositoryPath, projectPath, @projectId, @@sphinxMakefileHead, @revision )

    #sphinxのMakefileのパス取得
    sphinxPath = searchMakefile( projectPath + "/" + @projectId + "/" + @revision, @@sphinxMakefileHead )
    #Makefileが存在するディレクトリ
    if( sphinxPath != nil && sphinxPath != "" ) then
      sphinxPathDir = sphinxPath.gsub( /(Makefile$)/ , "")
    end

    @document = "Sphinx Document Not Found."
    #ドキュメントが見つかったかどうか
    found = false
    if( sphinxPathDir != nil ) then

      #Makefile内からbuild先のディレクトリ名を取得
      buildDirName = getBuildDir( sphinxPath )
      
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
        serverIndexPath = indexPath.gsub( @@projectPath, "" )

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
      #      render :text => @documentPathAtServer
      redirect_to @documentPathAtServer
      #    else
      #      render :text => @document
      #viewerに処理を渡す
    end
  end

  #初期ページ
  def index
    @project = Project.find( params[:project_id] )
    @projectId = params[:project_id]
    @repository = @project.repository
    @changeset = @repository.changesets
  end

  private 

  #sphinx makefileの場所を探す
  #このあたりの処理はhelperに書いた方がよい
  def searchMakefile(path, sphinxMakefileHead)

    if FileTest.directory?( path ) then
      Dir.glob( "#{path}/**/Makefile" ).each do |filepath|
        makefile = File.open( filepath )
        #先頭文字列読み出し                                                                                                                
        headdata = makefile.gets
        makefile.close

        if headdata.start_with?( sphinxMakefileHead) then
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
  def getBuildDir( path )
    begin
      makefile = File.open( path )
      makefile.each do | line |
        data = line.gsub(" ","")
        data = data.gsub("\t","")

        if( data.start_with?( @@buildDirVariableName + "=") )
          ret = data.gsub( @@buildDirVariableName + "=", "")
          ret.strip!
          return ret
        end
      end
      makefile.close
    rescue Exception => e
      puts "Cannot open file( path:" + path.to_s + " )"
      puts e
      puts e.backtrace
    end
    return nil
  end

  #repositoryからsphinxドキュメントを取得してcompile
  #argument:
  #  gitRepositoryPath: git repositoryのおいてあるpath
  #  temporaryPath: 一時的にコンパイル済みsphinxデータをおいておくpath
  #  redmine: project名
  #  sphinxMakefileHead: sphinxのmakefileのheadにある文字列
  #  revision: revision名
  def compileSphinx( gitRepositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision )
    #TODO: こんな風にコマンド組み込んでいいのか?修正を検討

    #既にコンパイル済みだったらいちいちmakeしない
    #TODO: コンパイルされているのをディレクトリの存在だけで判断していいのか?
    if File.exists?( "#{temporaryPath}/#{redmineProjectName}/#{revision}" ) then
      return
    end

    #git cloneを行って、適当なディレクトリにデータを取得する
    gitCloneCommand = "git clone #{gitRepositoryPath} #{temporaryPath}/#{redmineProjectName}/head"

    system( gitCloneCommand )
    #puts "command :" + gitCloneCommand
    #git pullでデータ取得
    gitDir = "#{temporaryPath}/#{redmineProjectName}"
    moveToGitDirCommand = "cd #{gitDir}/head"
    gitPullCommand = "git --git-dir=.git pull"

    #git pullを行ってheadデータ取得
    system( moveToGitDirCommand + ";" + gitPullCommand )

    #git revision copyを行う
    copyCommand = "cp -rf #{gitDir}/head/ #{gitDir}/#{revision}"
    checkoutCommand = "cd #{gitDir}/#{revision}" + ";" + "git checkout #{revision}" 
    system( copyCommand )
    system( checkoutCommand )

    doc = searchMakefile( "#{temporaryPath}/#{redmineProjectName}/#{revision}", sphinxMakefileHead )
    if( doc != nil ) then
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd #{doc}; make html")
    end
  end
end
