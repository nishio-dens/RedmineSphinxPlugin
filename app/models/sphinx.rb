# -*- coding: utf-8 -*-

class Sphinx 

  require 'shellwords'

  def self.search_redirect_path( projectId, revision, request )
    #sphinx server setting
    sphinxSetting = SphinxPluginSettings.sphinx
    serverSetting = SphinxPluginSettings.server

    projectPath = serverSetting.document_root_path + serverSetting.sphinx_dir
    sphinxPath = search_makefile( projectPath + "/" + projectId + "/" + revision, sphinxSetting.sphinx_makefile_head )
    if sphinxPath
      sphinxPathDir = sphinxPath.gsub( /(Makefile$)/ , "")
    end

    if sphinxPathDir
      buildDirName = get_build_dir( sphinxPath )

      if buildDirName
        indexPath = sphinxPathDir + buildDirName + "/html/" + sphinxSetting.sphinx_index_page
      else
        sphinxDefaultBuildDir = "build/html/"
        indexPath = sphinxPathDir + sphinxDefaultBuildDir + sphinxSetting.sphinx_index_page
      end

      exist = File.exists?(indexPath)
      if exist
        serverIndexPath = indexPath.gsub(serverSetting.document_root_path, "")

        serverAddress = request.headers['SERVER_NAME']
        serverPort = request.headers['SERVER_PORT']
        if serverSetting.server_port
          serverPort = serverSetting.server_port
        end

        documentPathAtServer = "http://" + serverAddress.to_s + ":" + serverPort.to_s + "/" + serverIndexPath
      end
    end
    return documentPathAtServer
  end

  #compile sphinx document
  def self.compile( projectId, revision, repository )
    sphinxSetting = SphinxPluginSettings.sphinx
    serverSetting = SphinxPluginSettings.server

    #absolute path
    projectPath = serverSetting.document_root_path + serverSetting.sphinx_dir;
    repositoryPath = repository.url
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

  #find sphinx makefile
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

  def self.get_build_dir( path )
    /^\s*#{SphinxPluginSettings.sphinx.build_dir_variable_name}\s*=\s*(.*)$/s =~ File.read(path)
    return $1
  end

  #get sphinx document and compile it
  def self.checkout_and_compile( driver, repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision, username, password )
    dirRevPath = "#{esc temporaryPath}/#{esc redmineProjectName}/#{esc revision}" 
    if File.exists?(dirRevPath)
      return
    end
    driver.checkout( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefileHead, revision, username, password )
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
