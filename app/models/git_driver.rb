# -*- coding: utf-8 -*-
class GitDriver 
  def checkout( repositoryPath, temporaryPath, redmineProjectName, sphinxMakefilehead, revision, username, password)
    dirPath = "#{esc temporaryPath}/#{esc redmineProjectName}"
    dirRevPath = "#{dirPath}/#{esc revision}" 
    dirHeadPath = "#{dirPath}/head"

    #git cloneを行って、head取得
    system("git","clone",repositoryPath, dirHeadPath)
    #git pullでデータ取得
    moveToGitDirCommand = "cd #{dirHeadPath}"
    gitPullCommand = "git --git-dir=.git pull"
    #git pullを行ってheadデータ取得
    system( moveToGitDirCommand + ";" + gitPullCommand )
    #git revision copyを行う
    system("cp","-rf", dirHeadPath, dirRevPath)
    #git checkoutを行う
    checkoutCommand = "cd #{dirRevPath}" + ";" + "git checkout #{esc revision}" 
    system(checkoutCommand)
  end

  private
  def esc(arg)
    Shellwords.shellescape(arg)
  end
end
