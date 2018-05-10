---
title: Tests fail at midnight
published: false
tags: ruby, rails, tests
---

I'm always making the same mistake with my tests. I write them, see them passed
and everything looks good before I run them after midnight. Have you ever had
experience with it? I think yes, everyone has to. I hope you know the reason why
they behave this way if it's happend to you and I'm going to give you decision.
First of all let's see the docs about how Rails works with time columns since
our mistake is time dependent.

ActiveRecord automatically updates fields named `created_(at|on)` or
`updated_(at|on)`. There's a setting that can change this behavior:
`config.active_record.record_timestamps`.

Rails API says that timestamps are in the `:local` timezone by default,
but you can set it to utc by: `config.active_record.default_timezone = :utc`.
Indeed they lie!

Here's the block of code from `activerecord\lib\active_record\railtie.rb`:

``` ruby
initializer "active_record.initialize_timezone" do
  ActiveSupport.on_load(:active_record) do
    ...
    self.default_timezone = :utc
  end
end
```

It's `:utc` by default in Rails, and it's `:local` if you use ActiveRecord out
of it. By the way they have already changed this behavior and Rails 4 gonna ship
with `:utc`. So what does this option do?

I have to say that my system time zone is Europe/Moscow (+4):

``` bash
$ sudo systemsetup -gettimezone
Time Zone: Europe/Moscow
```

And I have to mention another setting named `config.time_zone` which is UTC
by default. All time aware fields will be converted to that timezone.

Let's consider a few examples:

``` ruby
User.connection.select_all("SELECT updated_at FROM users WHERE users.id = 1")
# => [{"updated_at"=>"2012-11-19 15:29:45.314649"}]
[Rails.application.config.time_zone, ActiveRecord::Base.default_timezone] # => ["UTC", :utc]
User.find(1).updated_at # => Mon, 19 Nov 2012 15:29:45 UTC +00:00
[Rails.application.config.time_zone, ActiveRecord::Base.default_timezone] # => ["Moscow", :utc]
User.find(1).updated_at # => Mon, 19 Nov 2012 19:29:45 MSK +04:00
[Rails.application.config.time_zone, ActiveRecord::Base.default_timezone] # => ["UTC", :local]
User.find(1).updated_at # => Mon, 19 Nov 2012 11:29:45 UTC +00:00
[Rails.application.config.time_zone, ActiveRecord::Base.default_timezone] # => ["Moscow", :local]
User.find(1).updated_at # => Mon, 19 Nov 2012 15:29:45 MSK +04:00
```

The first query gives us the real value from the database without time zone
offset. I show you the settings each time before I try to call `updated_at`.
First result gives us the same value as in the database because
time zones are the same. It retrieves value from the database and supposes that
it's in UTC because of `config.default_timezone`, than checks
`config.time_zone` setting and understands that they are the same.
Second result adds 4 hours because `config.time_zone` is set to Moscow and it
supposes that time from the database is in UTC.
All next cases are with `config.default_timezone` is set to `:local`.
In the third case ActiveRecord supposes that value in the database is
in the local time zone, so `2012-11-19 15:29:45.314649` is by Moscow, but
`config.time_zone` is set to UTC so we need deduct 4 hours. And last but not
least case, it supposes value from the database by Moscow time and
`config.time_zone` is set to the same timezone too, so it doesn't do anything.
As you found out `config.default_timezone` setting works when you pull dates and
times from the database. Now I think you got the main idea, didn't you?

A little quiz for you, I suppose you're on my laptop and now you have these
settings in your application.rb:

``` ruby
config.time_zone = 'Central America' # It's (-6)
config.active_record.default_timezone = :local
```

Give me the answer what will return ActiveRecord for updated_at?

``` ruby
# => [{"updated_at"=>"2012-11-19 15:29:45.314649"}]
[Rails.application.config.time_zone, ActiveRecord::Base.default_timezone] # => ["Central America", :local]
User.find(1).updated_at # => ???
```

Ok if you said `Mon, 19 Nov 2012 05:29:45 CST -06:00` you were good boy.
When ActiveRecord retrieves the value it supposes that it's in local time zone.
Which zone is local for me? Yep, system time zone is local for me and it's
Moscow! So in UTC it will be `2012-11-19 11:29:45` and minus six hours it will
be exactly `2012-11-19 05:29:45`.

Let's move on. By default, ActiveRecord keeps all the datetime columns time zone
aware relying on: `config.active_record.time_zone_aware_attributes = true`.

If your attributes are time zone aware and you desire to skip time zone
conversion to the current Time.zone when reading certain attributes then you can
do following:

``` ruby
class Topic < ActiveRecord::Base
  self.skip_time_zone_conversion_for_attributes = [:written_on]
end
```
