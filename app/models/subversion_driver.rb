class SubversionDriver
  def checkout( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefilehead, revision, username, password)
    dirPath = "#{esc temporaryPath}/#{esc redmineProjectName}"
    dirRevPath = "#{dirPath}/#{esc revision}" 
    #subversion checkout
    system("svn", "checkout", "#{repositoryPath}@#{revision}", "--username", username, "--password", password, dirRevPath)
  end

  private
  def esc(arg)
    Shellwords.shellescape(arg)
  end
end
