---
title: Slow query with ActiveRecord's method first
tags: ruby, rails, activerecord, sql
description: Postgresql slow query with limit 1
---

If you've grown with Rails like me you know that everyone used and perhaps still
uses everywhere `first` method. You just type it automatically. I know that it's
so simple that it doesn't even deserve a post but you have to stop doing that.

<img src="/images/irb.png" class="img-fluid" alt="irb">

Things are getting more intersting with PostgreSQL v10:

```sql
EXPLAIN ANALYZE SELECT * FROM "posts" WHERE "posts"."deleted_at" IS NULL AND "posts"."user_id" = 1 order by id ASC limit 1;
                                                                    QUERY PLAN                                                                    
--------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.11..26.91 rows=1 width=327) (actual time=37557.875..37557.875 rows=1 loops=1)
   ->  Index Scan using posts_pkey on posts  (cost=0.11..2057670.78 rows=76800 width=327) (actual time=37557.874..37557.874 rows=1 loops=1)
         Filter: ((deleted_at IS NULL) AND (user_id = 1))
         Rows Removed by Filter: 26826499
 Planning time: 0.202 ms
 Execution time: 37557.905 ms
(6 rows)
```

Doesn't it look creepy? According to [stackoverflow](https://stackoverflow.com/questions/21385555/postgresql-query-very-slow-with-limit-1)
it can be an issue in the planner and given that you have pretty large table
this query becomes drastically slower than planned. So a combination of two
issues results in a waste of time for investigation. First of all it shouldn't
have happened if we used `take` method added [long ago](https://github.com/rails/rails/commit/1379375f93c53d4c49fa8592b6117c3ade263f2e):

```sql
EXPLAIN ANALYZE SELECT * FROM "posts" WHERE "posts"."deleted_at" IS NULL AND "posts"."user_id" = 1 limit 1;
                                                     QUERY PLAN                                                     
--------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.00..13.40 rows=1 width=327) (actual time=1.979..1.979 rows=1 loops=1)
   ->  Seq Scan on posts  (cost=0.00..1029108.93 rows=76800 width=327) (actual time=1.978..1.978 rows=1 loops=1)
         Filter: ((deleted_at IS NULL) AND (user_id = 1))
         Rows Removed by Filter: 3463
 Planning time: 1.606 ms
 Execution time: 2.047 ms
(6 rows)
```

Force yourself typing `take` instead of `first` if you don't care about the
order which in most cases is true.