Time.zone = 'Moscow'

set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true, smartypants: true
activate :syntax

# Overwrite it because of line numbers, and missing '>' at closing table tag.
class Middleman::Renderers::MiddlemanRedcarpetHTML
  def block_code(code, language)
    table = Pygments.highlight(code, lexer: language, options: { linenos: true }) << '>'
    "<div class='codeblock'>#{table}</div>"
  end
end

activate :blog do |blog|
  blog.sources = 'posts/:year-:month-:day-:title.html'
  blog.layout = 'post'

  blog.tag_template = 'tag.html'
  blog.calendar_template = 'calendar.html'
end

page '/feed.xml', layout: false

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'
