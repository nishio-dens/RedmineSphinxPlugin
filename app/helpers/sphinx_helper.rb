# -*- coding: undecided -*-
module SphinxHelper
  #あまりに文章が長い場合はカットする
  def truncate_at_line_break(text, length = 255)
    if text
      text.gsub(%r{^(.{#{length}}[^\n]*)\n.+$}m, '\\1...')
    end
  end
end
