# Analyzing SQL Performance

From time to time you may want to see if the queries hitting the PostgreSQL server are the cause of your slowness. This could be because of missing indexes on the tables, or suboptimal queries.

Most of our commons have been configured with a RDS parameter group which turns on detailed logging for every SQL query run. To analyze the logs you should download them from the AWS console or using the awscli command on the adminwm.

You can download several hours worth of logs, and then analyze them using [pgBadger](https://github.com/darold/pgbadger). Here is a Docker command to run pgBadger over some log files in the current directory.

```bash
docker run --rm -v ${PWD}:/outdir dalibo/pgbadger -O /outdir -p '%t:%r:%u@%d:[%p]:' -f stderr "/outdir/sqllog1.txt" "/outdir/sqllog2.txt"
```

where `sqllog1.txt` and `sqllog2.txt` are log files you downloaded. You can append more log files to the command as needed. This will produce an `out.html` in the current directory which contains the results of the analysis.

The most interesting results are likely contained under the Top -> Time consuming queries menu.
