---
title: Rails autoloading
tags: ruby, rails, require, load, autoload, constant resolution, autoloading
---

There is much to be said about Rails autoloading and particularly about
`ActiveSupport::Dependencies` (`AS::D` for short). What does it do? As the title
says it loads constants automatically and reloads your code catching changes on
every request. Ok, why do we need it? Because it's convenient! We don't have to
write `require` in every single file and watch which constants we need and when.
Rails loads constants and tracks what we need automatically. Also there's no
need to reload your server every time you've made a change. There are some
pitfalls that you must know, but once you learn them everything will be ok.


### How it works

Previously discussed method `self.const_missing(const_name)` is the entry point
for `AS::D`. Consider this example:

``` ruby
# /autoloadable/a.rb
# module A
# end

require 'active_support/dependencies'
ActiveSupport::Dependencies.autoload_paths = ['/autoloadable']

A
```

`AS::D` loads module `A` automatically without any `require`.

``` ruby
# Meanwhile you can add sleep here and make changes in a.rb

ActiveSupport::Dependencies.clear # Removes A from memory

A # Will load A again
```

I've just introduced the method Rails reloads your code with — `clear`. Let's
dig dipper and see how `AS::D` actually works. There are two different constant
loading strategy: `:require` and `:load`(default). The first one means that all
the constants won't be reloaded, as `require` does eventually. The last one
means that all the constants will be removed from memory and loaded again on
demand. What does removing constant from memory mean? There's a method called
`Module#remove_const(sym)`:

``` ruby
module A; end
Object.send(:remove_const, 'A')
A # => uninitialized constant A (NameError)
```

But what if we remove constant for existing instance of a class:

``` ruby
class A
  def self.value
    'value'
  end
end

a = A.new
Object.send(:remove_const, 'A')
a.class # => A
a.class.value # => 'value'
A # => uninitialized constant A (NameError)
```

That's interesting because constant name was removed from memory but its
instance still shows us its class and we can even call class methods on it. It
turns out that this method only removes constant name from `Object` but a class
is an object and a constant is a variable referencing that object still exists
in the memory. Ok, move on.

Calling `require 'active_support/dependencies'` injects a few modules into basic
Ruby classes via `AS::D.hook!`.

``` ruby
def hook!
  Object.class_eval { include Loadable }
  Module.class_eval { include ModuleConstMissing }
  Exception.class_eval { include Blamable }
end
```

Methods injected into `Object` overwrite methods like `load` and `require` in
order to monitor new constants, that said, it depends on loading strategy.
Another method you could already know is `require_dependency` also injected into
`Object`. Methods in `Module` define an entry point `const_missing`. I'm going
to show you how `AS::D` works with this example:

``` ruby
# /autoloadable/a.rb
# module A
# end

require 'active_support/dependencies'
ActiveSupport::Dependencies.autoload_paths = ['/autoloadable']

A
```

1. Declaring constant `A` triggers `Module#const_missing`, that was overwritten
by `AS::D` and `Dependencies.load_missing_constant(from_mod, const_name)` is
invoked. The first argument is `Object` because `A == Object::A` the second is
`:A`.
2. `load_missing_constant` tries to find the path for this constant which by
convention lies somewhere in one of the `autoload_paths` by means of
`search_for_file('a')`. It just returns the first file it can find with
`File.file?(File.join(autoload_path, 'a.rb'))`
3. Then `require_or_load` method is invoked, whose behavior depends on loading
strategy. For `require` it just requires the given file, for `load`
`load_file('/autoloadable/a.rb', 'A')` is invoked.
4. Then it looks for new constants in given namespaces with:
`new_constants_in(*parent_paths) { Kernel.load(path) }`
where `parent_paths` is `[Object]`, because we try to resolve `Object::A` and
`path` is the path to file. How does it monitor it? It's just the difference
between the array of constants before and after. `Object.local_constants` gives
us all the constants inside `Object`.
5. When it's done, all newly defined constants append to `autoloaded_constants`.
That's all, new constant was defined with `AS::D`

`AS::D.clear` removes constants from memory and clears all the auto-loaded
constants inside `AS::D`. Pay your attention to `require_dependency`. This
method adds all newly defined constants to `autoloaded_constants` so that they
will be reloaded unlike the `require` method.

Another convention `AS::D` uses is a path convention. This example
`'A::B'.underscore # => 'a/b'` simply illustrates that `::` is treated as a `/`,
which gives us ability to use folders like module namespaces:

``` ruby
# /autoloadable/a.rb
# module A
# end

# /autoloadable/a/b.rb
# module A
#   module B
#     C = 'c'
#   end
# end

A::B::C => 'c'
```

or even so:

``` ruby
# /autoloadable/a/b.rb
# module A::B
#   C = 'c'
# end

A::B::C => 'c'
```

Although we haven't defined module `A`, it has been created for us automatically
because of existing directory `a`. It's really convinient, because you are not
forced to create an empty module just for namespacing purpose.


### Misconception

Since Ruby passes only one argument to `const_missing(const_name)` we don't have
an idea about the nesting, this example works as expected:

``` ruby
# /autoloadable/b.rb
module B
end

# /autoloadable/a.rb
module A
  B # => B
end
```

but this shows wrong results:

``` ruby
# /autoloadable/a.rb
module A
end

# /autoloadable/b.rb
module B
end

p A::B # => B
```

Is that right? I don't think so. If we had used pure Ruby it would have thrown
`NameError: uninitialized constant A::B`, because we explicitly said we need `B`
inside of `A` but not the top-level `B`. But this is Ruby's fault it passes so
little info to `const_missing` and `AS::D` can do nothing with it.

Another cool case:

``` ruby
# /autoloadable/a.rb
# module A; end

# /autoloadable/namespace/a/b.rb
# module Namespace::A::B
#  A
# end

Namespace::A::B # => What is A inside this namespace?
```

What would you expect from this example? I think in Ruby it's obviously
top-level `A`, but since `AS::D` doesn't know about nesting, would you expect it
to be either `Namespace::A` or `A`? Neither, because it's `NameError`, which is
much more confusing. It's the last attempt of `AS::D` to make an assumption that
since one of our parents has this constant
`Namespace.const_defined?(:A, false) # => true` then we're definitely looking
for this constant in a short form `from_mod::const_name`, otherwise Ruby would
return it without calling `const_missing` and we don't have to search it upwards
in `from_mod`. Why don't we have to search it right at the top-level? May be
because of this:

``` ruby
# c.rb
# C = 'c'

# a/c.rb
# module A
#   C = 'ac'
# end

# a/b.rb
# module A::B
#   C
# end

A::B::C # => 'ac'
A::B::C # => uninitialized constant A::B::C
```

Calling it twice gives us an error, because of the same case we've considered
above. The first time `AS::D` resolves `C` through as usual, but the second time
it starts checking enclosing modules and since `A` contains `C` then Ruby must
have resolved it or otherwise it's the short form and an error is thrown.
Imagine we've fixed it and instead of error we start loading top level constant.
Is it any better? Now we have two different constants calling it twice in a row,
which is still sad. That's why I'd prefer an error.


### Thread safety

Let's write our own simplified autoloading:

``` ruby
# autoloadable/a.rb
# module A
#   sleep 5
#   def self.hello
#     'hello'
#   end
# end

class Module
  def const_missing(name)
    require "./autoloadable/#{name.downcase}.rb"
    Object.const_get(name)
  end
end

t1 = Thread.new { A.hello }
t2 = Thread.new { A.hello }
t1.join; t2.join
```

The result is `undefined method 'hello' for A:Module (NoMethodError)`. Why?
Because second thread takes over when the first is awaiting sleeping. At that
moment module `A` is already defined but method `hello` isn't defined yet. It
turns out that `AS::D` will never be thread safe until `const_missing` isn't
thread safe. That's the reason why your production environment loads all the
constants on initialization step. In fact, you can see different errors even
with MRI, because it switches threads when waits for input-ouput or network. For
instance, circular dependency arises, when the first thread waits for
input-ouput and another thread starts resolving the same constant, which is
already in the list of loaded.


### Known errors

* Toplevel constant B referenced by A::B

Have you ever seen the 'Toplevel constant B referenced by A::B'? It's easy to
reproduce even without `AS::D`:

``` ruby
class B; end
class A; end

A::B
```

Since `A.ancestors` is `[A, Object, Kernel, BasicObject]` and contains class
`Object` and `B` are already defined as top level constants, Ruby shows us a
warning that constant we're trying to resolve inside `A` references top level
constant. Notice that for modules the situation is different:

``` ruby
module B; end
module A; end

A::B
```

It gives us just 'uninitialized constant A::B (NameError)' because the ancestors
chain doesn't contain `Object`.

* Circular dependency detected while autoloading constant

This is yet another `AS::D` error that you could see:

``` ruby
# /autoloadable/a.rb
# B
# module A
# end

# /autoloadable/b.rb
# A
# module B
# end

A
```

If we try to access constant `A` we'll see this error. `AS::D` makes an
assumption that this constant is defined in file `a.rb`. When it loads this file
it finds another undefined constant `B` and this time faces still undefined `A`
while loading file `b.rb`. This generates infinite recursion and to prevent it
an error must be raised. This error as and many others also appears in
multi-threaded environment.

* A copy of `A` has been removed from the module tree but is still active!

``` ruby
# /autoloadable/money.rb
# class Money
# end

# /autoloadable/customer.rb
# class Customer
#   def money
#     Money.new
#   end
# end

customer = Customer.new

ActiveSupport::Dependencies.clear

customer.money
```

It happens because class for `Customer` was autoloaded, but class for `Money`
wasn't because we haven't invoked `Money.new` before `AS::D.clear`. Then
`Customer` was removed as a reference, but instance of this class is still in
memory, and then we're trying to resolve constant name `Money`, but for
`customer.class::Money` which is different from newly loaded `Customer`. Please
note that saving the whole instance somewhere between sessions increases chances
you'll see this error.


### Conclusion

You don't have to care about all this stuff if you have flat hierarchy. It means
when you don't use namespaces and all the files have different names, but it's
hard if you have a lot of classes/modules. So you must have clear understanding
of this if you don't want to be in trouble:

* Don't use the same name for top-level and namespaced constants.

* Be careful when you use short form declaration unless you know what you do.

* Be careful if you use short form declaration and it contains the name of the
constant you try to resolve, use full path instead.

* Carefully work with constants in initializers, you may declare new constant
instead of loading original.

* Try to run you application with eager loading or in production mode since it
may load your code in another order.


### Links and used sources:

* [Eager loading](http://blog.plataformatec.com.br/2012/08/eager-loading-for-greater-good/)
* [Rails autoloading](http://urbanautomaton.com/blog/2013/08/27/rails-autoloading-hell/)
* [Removing config.threadsafe!](http://tenderlovemaking.com/2012/06/18/removing-config-threadsafe.html)
