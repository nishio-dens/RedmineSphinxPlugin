# -*- coding: utf-8 -*-
class GitDriver 
  def checkout( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefilehead, revision, username, password)
    dirPath = "#{esc temporaryPath}/#{esc redmineProjectName}"
    dirRevPath = "#{dirPath}/#{esc revision}" 
    dirHeadPath = "#{dirPath}/head"

    #git clone, and get HEAD
    system("git","clone",repositoryPath, dirHeadPath)
    #git pull
    moveToGitDirCommand = "cd #{dirHeadPath}"
    gitPullCommand = "git --git-dir=.git pull"
    #git pull and get HEAD
    system( moveToGitDirCommand + ";" + gitPullCommand )
    #git revision copy
    system("cp","-rf", dirHeadPath, dirRevPath)
    #git checkout
    checkoutCommand = "cd #{dirRevPath}" + ";" + "git checkout #{esc revision}" 
    system(checkoutCommand)
  end

  private
  def esc(arg)
    Shellwords.shellescape(arg)
  end
end
