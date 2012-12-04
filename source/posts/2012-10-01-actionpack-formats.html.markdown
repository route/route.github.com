---
title: ActionPack formats
published: false
categories: ruby, rails, actionpack
---


Hi there, today I want to share with you info about how ActionPack works with
formats. I faced this issue 2 month ago when I was trying jbuilder. Jbuilder is
a nice gem, it can render json templates/partials and has additional cool stuff.
I had to render html template with json pieces in my application.
To implement this I've just used usual render partial in my html template:

``` ruby
  :javascript
    #{render partial: "json_partial", formats: :json}
```

But there is a trouble here, if your json template contains
`json.partial! "file_name"`, it won't find that template.
As you know each request has its own headers, and Accept header is one of them.
I won't explain [it](http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1)
because you can read yourself. When you click link or change location, your
browser sends `Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`
to server. Rails parse headers and setup incoming formats:

``` ruby
  # actionpack/action_controller/metal/rendering.rb
  # Before processing, set the request formats in current controller formats.
  def process_action(*) #:nodoc:
    self.formats = request.formats.map { |x| x.ref }
    super
  end
```

Then it processed action in your controller, find template for your action
recline against formats, and return response to browser. There's a little thing
here, Rails use different renderers for templates and partials. TemplateRenderer
overwrites formats each time you use it. It seems legit because in usual cases
you render only

For our case formats are set to `[:html]`. When your action processed, rails
start lookup template for your action recline against formats. They found our
html template, then see render partial, but we set formats as :json for 
case, and they found it too. Next 
