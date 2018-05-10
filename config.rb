activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

activate :syntax, line_numbers: true

activate :blog do |blog|
  blog.sources = "posts/:year-:month-:day-:title.html"
  blog.layout = "post"
  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"
end

set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true, smartypants: true


page "/*.xml", layout: false
page "/*.json", layout: false
page "/*.txt", layout: false
