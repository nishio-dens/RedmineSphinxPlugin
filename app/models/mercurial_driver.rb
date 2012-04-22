# -*- coding: utf-8 -*-
class MercurialDriver
  def checkout( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefilehead, revision, username, password)
    dirPath = "#{esc temporaryPath}/#{esc redmineProjectName}"
    dirRevPath = "#{dirPath}/#{esc revision}" 

    #Make temporary directory for checkout
    FileUtils.mkdir_p( dirRevPath ) 
    system("hg","clone", repositoryPath, dirRevPath)
    #checkout
    moveDirCommand = "cd " + dirRevPath 
    checkoutCommand = "hg checkout #{esc revision}"
    system( moveDirCommand + ";" + checkoutCommand )
  end

  private
  def esc(arg)
    Shellwords.shellescape(arg)
  end
end
