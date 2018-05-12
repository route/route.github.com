---
title: See the difference
tags: ruby, rails
---

Yesterday I faced the strange behaviour of the array wrapping in context
of Arel. I tried to wrap something like this `User.arel_table[:id]` but
`Array(User.arel_table[:id])` and `Array.wrap(User.arel_table[:id])`
gave me different results. Now I'll tell you why you have to know about
some differences in array wrapping and why Rails contains their own wrap
realization.

You probably know about
[Array.wrap](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/array/wrap.rb#L36)
in Rails but if you don't here you are:

``` ruby
def self.wrap(object)
  if object.nil?
    []
  elsif object.respond_to?(:to_ary)
    object.to_ary || [object]
  else
    [object]
  end
end
```

And you probably know about
[Kernel#Array](http://rxr.whitequark.org/mri/source/object.c#2624):

```c?line_numbers=true
VALUE
rb_Array(VALUE val) {
  VALUE tmp = rb_check_array_type(val);

  if (NIL_P(tmp)) {
    tmp = rb_check_convert_type(val, T_ARRAY, "Array", "to_a");
    if (NIL_P(tmp)) {
      return rb_ary_new3(1, val);
    }
  }
  return tmp;
}

static VALUE
rb_f_array(VALUE obj, VALUE arg) {
  return rb_Array(arg);
}
```

Let's talk about ruby realization first of all.
When you invoke `Array(object)`, ruby will try to convert object into array
by means of `rb_check_array_type(val)` call. At the first step this
function will try to invoke `to_ary` and if it's defined and result differ
from `nil` and the same class as and `Array` it'll be returned.
The second step (Line 6) (if result of the first step was `nil`)
is `to_a`, here is the same thing as described above. The third and final
step (Line 8) (if steps above return `nil`) is new array will be created
with object as its element.

Now take a look at Rails realization. If object is `nil` it returns empty
array. If object responds to `to_ary` method it returns the result
or if the result is `nil` just `[object]`. And finally it returns
`[object]`.

You see that Rails method doesn't call `to_a`.
And one thing I haven't mentioned is raise. Yep. Ruby version will raise
exception if object that you return in `to_ary` or `to_a` methods isn't
`Array`.

Now you and me know why `Array(object)` returns me not what I wanted
because of overridden `to_a` method in Arel.
And in my case I select Rails version of course.

There are things I have never thought about and just used them.
They seemed to me very simple but in reality they are tiniest bits of a big
complicated mechanism. We use too many abstraction levels and work on the top
of it and rely on it. You should be waiting for troubles from everywhere.
