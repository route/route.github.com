---
title: Query Trail
tags: ruby, rails, sql, query, logger
---

Recently I switched on a project with lots of legacy code. It was on Rails 2,
Rails 3 and now I've updated it to Rails 4.1. You can't even imagine how much
rubbish I got rid of. But the thing I'd like to share with you today is
[QueryTrail](https://github.com/route/query_trail). This simple but useful gem
shows you the backtrace of fired queries. You have to agree that when just one
action of your controller sends hundreds sql requests from helpers, templates
and so forth, it's definitely hard to locate the place for specific query. But
not for now:

```
User Load (0.4ms)  SELECT  `users`.* FROM `users`  WHERE `users`.`id` = 1 LIMIT 1
Query Trail: config/initializers/warden.rb:11:in `block in <top (required)>'
             config/initializers/warden.rb:15:in `block in <top (required)>'
Doc Load (18.2ms)  SELECT `docs`.* FROM `docs`  WHERE `docs`.`approved` = 1
Query Trail: app/views/main/_docs.html.erb:2
             app/helpers/docs_helper.rb:3:in `render_main_block'
             app/views/main/index.html.erb:13
             app/views/main/index.html.erb:9
```
