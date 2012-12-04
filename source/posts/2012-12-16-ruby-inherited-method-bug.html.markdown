---
title: Ruby inherited method bug
tags: ruby, rails
---

This post is about the bug I found when I was writing tests for `quiet_assets`.
I won't show you all those tests, just a small piece:

``` ruby
  Class.new(Rails::Application) do
    routes.append { ... }
  end
```

All of them were passed on my laptop, but Travis-CI showed me the odd message
for Ruby 1.8:
`undefined local variable or method 'routes' for #<Class:0xb6b9a92c>`.
It says that there's no such method `routes` inside dynamically generated class,
but it works for Ruby 1.9. What's wrong with it? Let's take a look at
Rails core. In our example we define dynamic class whose parent is
`Rails::Application` that inherited from class `Rails::Engine` that inherited
from `Rails::Railtie`. You can find `routes` definition at line 488 of
`Rails::Engine`. I consider only 3-2-stable branch in my post. It's defined as
an instance method. How can it be possible to use it on the class level?
If you take a look at the chain of `self.inherited` callbacks in all those
classes you'll see that `Rails::Railtie` has module inclusion:

``` ruby
  def inherited(base)
    ...
    base.send(:include, Railtie::Configurable)
  end
```

`Railtie::Configurable` has `method_missing` which does exactly our case -
proxying our calls to instance. You see that all logic rely on `self.inhereted`
callback. Let's check it:

``` ruby
  class Parent
    def self.inherited(base)
      puts 'Inside inherited'
    end
  end

  class Child < Parent
    puts 'We are inside class definition'
  end

  app = Class.new(Parent) do
    puts 'We are inside class definition'
  end
```

If you run this code you'll see that for `Class.new` we'll get this:

```
  We are inside class definition
  Inside inherited
```

Ruby 1.8 cannot find `routes`, even `method_missing` just because
`self.inherited` chain couldn't be invoked inside our block, it would be
invoked after class definition. Be careful!
