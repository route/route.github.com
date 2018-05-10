---
title: Stop using ActiveRecord's first method
tags: rails, activerecord, postgresql
description: ActiveRecord slow query with limit 1. Postgresql query very slow with limit 1.
keywords: rails, activerecord, first, postgresql planner, postgresql scheduler, slow query, limit 1
---

If you've grown with Rails like me you know that everyone used and perhaps still
use everywhere `first`. You type it without hesitation.

![hacking](/images/irb.png)

I know that it's so simple that maybe it even doesn't deserve a post but just
stop doing that.

There's a much better method [take](https://github.com/rails/rails/commit/1379375f93c53d4c49fa8592b6117c3ade263f2e)
added long ago Apr 27, 2012 and if you say right now:

\- I know all that!

then things are getting more intersting with PostgreSQL v10 at least:

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
it can be an issue in the planner and given that you have pretty large table not
with 10 posts of course this query becomes drastically slower than planned. So a
combination of two issues results in a waste of time for investigation. First of
all it shouldn't have happened if we used `take`:

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

Force yourself typing `take` instead of `first` if you don't care about the order
which in most cases is the case.
