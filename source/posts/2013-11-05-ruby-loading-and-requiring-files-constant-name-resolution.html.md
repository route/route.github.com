---
title: Ruby loading and requiring files, constant name resolution
tags: ruby, require, load, autoload, constant resolution
---

This article has started as my own research on a slightly different theme —
[Rails autoloading](/2013/11/13/rails-autoloading.html), but I couldn't describe
it without saying a single word about Ruby itself. In this topic we'll talk
about how Ruby loads and requires modules, constant name resolution and then
we'll switch to [Rails autoloading](/2013/11/13/rails-autoloading.html). There's
more or less info about all these topics on the internet, so that sometimes I'll
be overlapping with it but sometimes not, I don't claim it's unique info but
anyway I have to sum it up in just one big article. So let's get started with
Ruby.

### Constant definition:

``` diff
A constant in Ruby is like a variable, except that its value is supposed to
remain constant for the duration of a program. The Ruby interpreter does not
actually enforce the constancy of constants, but it does issue a warning if a
program changes the value of a constant. Lexically, the names of constants look
like the names of local variables, except that they begin with a capital letter.
By convention, most constants are written in all uppercase with underscores to
separate words, LIKE_THIS. Ruby class and module names are also constants, but
they are conventionally written using initial capital letters and camel case,
LikeThis.

The Ruby Programming Language: David Flanagan; Yukihiro Matsumoto.
```

I think it's clear and turns out that we'll see a warning if we'll try to change
a constant:

```ruby
A = 'a'
A = 'b'
#./a.rb:2: warning: already initialized constant A
#./a.rb:1: warning: previous definition of A was here
```

The same thing for classes:

```ruby
class A; end
A = 'b'
#./a.rb:2: warning: already initialized constant A
#./a.rb:1: warning: previous definition of A was here
```

Since the constant `A` is just a reference for the class' object (remember class
is object in Ruby, right?) and we try to reassign it with new value then we see
this warning. Ok, now we know what the constant is, moving to files requiring.

### Loading and requiring files

We cannot place all the code in just one single file, otherwise it would be too
long and complicated for reading. Usually we put a class per file and use a few
different methods in order to 'concatenate' it. Here they are: `require`,
`require_relative`, `load`, `autoload`. Let's start with the first one.

`Kernel#require(name)` loads the given name, returning `true` if successful and
`false` if the feature is already loaded. If the filename does not resolve to an
absolute path, it will be searched for in the directories listed in
`$LOAD_PATH ($:)`. Any constants or globals within the loaded source file will
be available in the calling program's global namespace. However, local variables
will not be propagated to the loading environment. With this method you can load
even native extension(`.so`, `.dll` or the others depending on current
platform). If you don't specify the extension Ruby starts with `.rb` and so on.
The absolute path of the loaded file is added to `$LOADED_FEATURES ($")`. A file
will not be loaded again if its path already appears in `$"`.
`Kernel.require_relative(name)` is almost the same as `require` but it looks for
a file in the current directory or directories that is relative to current.

Example with `require`:

``` ruby
# a.rb
# module A
#   C = 'constant'
# end

before = $".dup
require 'a'
$" - before # => ['/Users/route/Projects/dependencies/a.rb']

A::C # => 'constant'
sleep 5
# Meanwhile changing constant value to 'changed'

require 'a'

A::C # => 'constant'
```

`Kernel#load(filename, wrap=false)` loads and executes the Ruby program in the
filename. If the filename does not resolve to an absolute path, the file is
searched for in `$:`. If the optional wrap parameter is true, the loaded script
will be executed under an anonymous module, protecting the calling program's
global namespace. It also can load the content of file many times because it
doesn't rely on `$LOADED_FEATURES`. Notice that `load` needs a filename
extension.

Example with `load`:

``` ruby
# a.rb
# module A
#   C = 'constant'
# end

before = $".dup
load './a.rb'
$" - before # => []

A::C # => 'constant'
sleep 5
# Meanwhile changing constant value to 'changed'

load './a.rb'

# ./a.rb:2: warning: already initialized constant A::C
# ./a.rb:2: warning: previous definition of C was here
A::C # => 'changed'
```

With warnings but the code was reloaded and we can even see the changes we've
made. Let's add optional parameter `wrap`:

Example with `load` and wrap:

``` ruby
# a.rb
# module A
#   C = 'constant'
# end
#
# $A = A

load './a.rb', true

A::C # => uninitialized constant A (NameError)
$A::C # => 'constant'
```

You see that Ruby hasn't polluted global namespace and wrapped all the constants
from the file to an anonymous module, but global variables still could be
retrieved.


`Kernel#autoload(module, filename)` registers filename to be loaded (using
`Kernel::require`) the first time that module (`String` or a `Symbol`) is
accessed.

Example 1 with `autoload`:

``` ruby
# a.rb
# module A
#   p 'loading'
# end

autoload :A, 'a'
```

It won't produce anything useful, because we've just declared that constant `A`
can be found in a file but we've never used it.

Example 2 with `autoload`:

``` ruby
# a.rb
# module A
#   p 'loading'
# end

autoload :A, 'a'
A # => Gives output 'loading'
```

In other words `autoload` makes us to load code lazily on demand decreasing time
during the boot. There were some problems with thread safety and `autoload`,
also there was a rumor that it would be deprecated, but I hadn't found any info
what the Ruby core team came up with. But the bug was fixed and I just can say
it works properly even with threads for now:

``` ruby
# a.rb
# module A
#   sleep 5
#   def self.hello
#     'hello'
#   end
# end

autoload :A, './a'

t1 = Thread.new { A.hello }
t2 = Thread.new { A.hello }
t1.join; t2.join
```

I was expecting that second thread would throw an error that method `hello` is
undefined because module `A` had been loaded by first thread but because of
sleep threads were switched, but it worked.

### Constant resolution

I find this example very comprehensive and I won't describe it much because the
code tells about itself:

``` ruby
module Kernel
  # Constants defined in Kernel
  A = B = C = D = E = F = 'defined in kernel'
end

# Top-level or 'global' constants defined in Object
A = B = C = D = E = 'defined at top-level'

class Super
  # Constants defined in a superclass
  A = B = C = D = 'defined in superclass'
end

module Included
  # Constants defined in an included module
  A = B = C = 'defined in included module'
end

module Enclosing
  # Constants defined in an enclosing module
  A = B = 'defined in enclosing module'

  class Local < Super
    include Included

    # Locally defined constant
    A = 'defined locally'

    # The list of modules searched, in the order searched
    # [Enclosing::Local, Enclosing, Included, Super, Object, Kernel, BasicObject]
    # (Module.nesting + self.ancestors + Object.ancestors).uniq
    puts A  # Prints "defined locally"
    puts B  # Prints "defined in enclosing module"
    puts C  # Prints "defined in included module"
    puts D  # Prints "defined in superclass"
    puts E  # Prints "defined at top-level"
    puts F  # Prints "defined in kernel"
  end
end
```

So the path Ruby follows in order to resolve constant name starts with
`Module.nesting` which of course starts with itself and then all enclosing
constants respectively. If the constant cannot be found there, then ancestors
chain is applied.

### Known pitfalls:

1) Nesting:

We can define new class/module using two different ways:

``` ruby
module A
  module B; end
end
```

or

``` ruby
module A; end
module A::B; end
```

Pay attention that `Module.nesting` for these two forms is different and turns
out that your constant name resolution will be different too:

``` ruby
module A
  C = 'c'
end

module A
  module B
    C # => 'c'
    Module.nesting # => [A::B, A]
  end
end

module A::B
  C # => NameError: uninitialized constant A::B::C
  Module.nesting # => [A::B]
end
```

2) Inheritance:

Remember that constants use the currently opened class or module, as determined
by `class` and `module` statements.

``` ruby
class Parent
  CONST = 'parent'

  def self.const
    CONST
  end
end

class Child < Parent
  CONST = 'child'
end

Child.const # => parent
```

In this example method is invoked on parent class, so its class is the innermost
one. To change things you could use `self::CONST` this way you're explicitly
saying find my constant in `self` where `self` is `Child` if we call
`Child.const`.

3) Object::

`Module.nesting == []` at the top level, and so constant lookup starts at the
currently opened class and its ancestors which is `Object`:

``` ruby
class Object
  module C; end
end
C == Object::C # => true
```

or

``` ruby
module C; end
Object::C == C # => true
```

This in turn explains why top-level constants are available throughout your
program. Almost all classes in Ruby inherit from `Object`, so `Object` is almost
always included in the list of ancestors of the currently open class, and thus
its constants are almost always available. That said, if you've ever used a
`BasicObject`, and noticed that top-level constants are missing, you now know
why. Because `BasicObject` does not subclass `Object`, all of the constants are
not in the lookup chain:

``` ruby
class Foo < BasicObject
  Kernel
end
# NameError: uninitialized constant Foo::Kernel
```

For cases like this, and anywhere else you want to be explicit, Ruby allows you
to use `::Kernel` to access `Object::Kernel`.

4) `class_eval`, `module_eval`, `instance_eval`, `define_method`:

As mentioned above, constant lookup uses the currently opened class, as
determined by class and module statements. Importantly, if you pass a block into
`class_eval`, `module_eval` or `instance_eval`, `define_method`, this won't
change constant lookup. It continues to use the constant lookup at the
point the block was defined:

``` ruby
class A
  module B; end
end

class C
  module B; end
  A.class_eval { B } == C::B
end
```

Confusingly however, if you pass a `String` to these methods, then the `String`
is evaluated with `Module.nesting` containing just the class/module itself (for
`class_eval` or `module_eval`) or just the singleton class of the object (for
`instance_eval`).

``` ruby
module A
  module B; end
end

module C
  module B; end
  A.module_eval("B") == A::B
end
```

``` ruby
module A
  X = 1
  module B; end
end

module C
  module B; end
  A::B.module_eval("X") # => uninitialized constant A::B::X (NameError)
end
```

5) Singleton class:

If you're in a singleton class of a class, you don't get access to constants
defined in the class itself:

``` ruby
class A
  module B; end
end
class << A
  B # => uninitialized constant Class::B
end
```

This is because the ancestors of the singleton class of a class do not include
the class itself, they start at the `Class` class.

``` ruby
class A
  module B; end
end
class << A
  ancestors # => [Class, Module, Object, Kernel, BasicObject]
end
```

Lastly, imagine we access a constant that isn't defined at all then
`self.const_missing` is invoked on the class that needs constant or if it wasn't
defined on that class it's invoked on its superclass — `Module`
(`A.class.superclass # => Module`). It accepts just one single argument
`const_name` which is the constant name we're looking for. By default this
method simply throws an error `NameError: uninitialized constant #{const_name}`.
That's all for Ruby moving to the more interesting part —
[Rails autoloading](/2013/11/13/rails-autoloading.html).

### Links and used sources:

* [Ruby-doc](http://ruby-doc.org)
* [Constant lookup](http://cirw.in/blog/constant-lookup)
* [Module.nesting and constant name resolution in Ruby](http://coderrr.wordpress.com/2008/03/11/constant-name-resolution-in-ruby/)
