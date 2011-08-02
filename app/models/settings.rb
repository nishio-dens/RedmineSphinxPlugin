# -*- coding: utf-8 -*-
require 'settingslogic'

class Settings < Settingslogic
  source "#{Rails.root}/config/sphinx_plugin_setting.yml"
  namespace Rails.env

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
  #sphinx Makefile内のbuildディレクトリを指定している変数名
  @@buildDirVariableName= Settings.sphinx.build_dir_variable_name

  #sphinx documentのコンパイル
  def compile_sphinx( projectId, revision, repository )
    #ドキュメントを設置する絶対パス
    projectPath = @@documentRoot + @@sphinxDir;
    #repositoryの取得
    repositoryPath = repository.url
    #リポジトリにあわせてsphinx documentをコンパイル
    case repository.scm
    when Redmine::Scm::Adapters::GitAdapter 
      compileGitSphinx( repositoryPath, projectPath, projectId, @@sphinxMakefileHead, revision )
    when Redmine::Scm::Adapters::SubversionAdapter
      username = repository.login
      password = repository.password
      compileSubversionSphinx( repositoryPath, projectPath, projectId, @@sphinxMakefileHead, revision, username, password )
    end
  end

  #sphinx makefileの場所を探す
  def search_makefile(path, sphinxMakefileHead)
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
  def get_build_dir( path )
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
  def compileGitSphinx( gitRepositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision )
    #TODO: こんな風にコマンド組み込んでいいのか?修正を検討
puts "file exist?:" + "#{temporaryPath}/#{redmineProjectName}/#{revision}"
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

    doc = search_makefile( "#{temporaryPath}/#{redmineProjectName}/#{revision}", sphinxMakefileHead )
    if( doc != nil ) then
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd #{doc}; make html")
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
  def compileSubversionSphinx( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision, username, password )
    #既にコンパイル済みだったらいちいちmakeしない
    if File.exists?( "#{temporaryPath}/#{redmineProjectName}/#{revision}" ) then
      return
    end

    #subversion checkout
    subversionCheckoutCommand = "svn checkout #{repositoryPath}@#{revision} "
    subversionCheckoutCommand = subversionCheckoutCommand + "--username #{username} --password #{password} #{temporaryPath}/#{redmineProjectName}/#{revision}"
    system( subversionCheckoutCommand )

    doc = search_makefile( "#{temporaryPath}/#{redmineProjectName}/#{revision}", sphinxMakefileHead )
    if( doc != nil ) then
      doc = doc.gsub( /(Makefile$)/ , "")
      system( "cd #{doc}; make html")
    end
  end
end
