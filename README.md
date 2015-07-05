edX Analytics Devstack
======================


This is a basic devstack setup for hacking on edX analytics.

It will setup:
* edx-analytics-pipeline
* edx-analytics-data-api
* edx-analytics-data-api-client
* edx-analytics-dashboard


Setup
-----

Make sure you have Vagrant and Ansible available on your system.
Then clone this repository, cd into it, and run `vagrant up`. Magic!

(Note it may take quite a while to provision the devstack at first - about 23
minutes on a MacBook Pro at the time of writing.)

If you want to update the system, try fixing bugs, or resume a failed
`vagrant up`, run the command `vagrant provision` to do so. You can re-provision
at any time. The provisioning process does not interfere with the cloned/shared
`edx-analytics-x` git repositories in any way, so no changes will be lost.


LMS Setup
---------
If you want to use this analytics devstack in concert with a local LMS devstack,
you'll need to make a few changes on the LMS devstack:

1. As the `vagrant` user, sudo edit `/etc/mysql/my.cnf` and change `bind-adress`
   from `127.0.0.1` to `0.0.0.0`.
2. Then run these commands:
  
   ```
   service mysql restart
   mysql -u root -e "GRANT SELECT ON *.* TO 'analytics'@'192.168.33.11' IDENTIFIED BY 'edx';"
   ```
3. Next, as the `edxapp` user, edit `lms/envs/private.py` and add:
  
   ```
   OAUTH_OIDC_ISSUER = 'http://192.168.33.10:8000/oauth2'
   ```
4. Finally, while the LMS is running, go to /admin/oauth2/client/ and add a new
   client with URL `http://192.168.33.11:9999/` and redirect URI
   `http://192.168.33.11:9999/complete/edx-oidc/`. Client type confidential.
   Save and leave the browser tab open as you'll need the client ID and secret
   when setting up the Insights dashboard (see "Usage" below).


Usage
-----

To do stuff, run `vagrant ssh` and then `sudo su analytics` to run commands.
You'll find all the apps in the `/home/analytics/apps` folder. Each app has
its own virtualenv in `/home/analytics/venvs/xxxxxx`, which will be
automagically activated for you when you `cd`, e.g. `cd ~/apps/pipeline`.

Ports are *not* forwarded, so you cannot access the apps via localhost:9999
(too prone to conflicts, with e.g. edX platform devstack). Instead, the
analytics devstack virtual box has the IP '192.168.33.11' so just connect
to that. For example, on your host computer, go to http://192.168.33.11:9999/

### To start the data API ###
Run this command as the `analytics` user:
```
cd ~/apps/data-api/ && ./manage.py runserver 0.0.0.0:9001
```
Access it at http://192.168.33.11:9001/

### To start the dashboard ###
* First, as a one time setup step, edit
`~/apps/dashboard/analytics_dashboard/settings/local.py` and set the values of
`SOCIAL_AUTH_EDX_OIDC_KEY` and `SOCIAL_AUTH_EDX_OIDC_SECRET` to the values
shown by the LMS in step 4 of "LMS Setup". Make sure the API server is running.

Then, as the `analytics` user:
```
cd ~/apps/dashboard/
make develop migrate
./manage.py runserver 0.0.0.0:9999
```
Access it at http://192.168.33.11:9999/

Notes:
* The data-api and the LMS must both be running for the dashboard to be fully
  functional.
* If you get timing errors during the OAuth login, run
  `sudo ntpdate -s time.nist.gov` on both devstacks to fix their clocks.


Tests
-----
To run the test suites of each of the four analytics apps:
```
vagrant up && vagrant ssh
sudo su analytics
cd ~/apps/pipeline/; make test
cd ~/apps/data-api/; make validate
cd ~/apps/data-api-client/; make test
cd ~/apps/dashboard/; make requirements.js; ./node_modules/.bin/r.js -o build.js; make validate
```


Testing the pipeline (Answer Distribution)
------------------------------------------
Let's try using the analytics pipeline to process data.

First, we need to make sure the Hadoop file system is available. Go to
http://192.168.33.11:50070/ and see if the status page loads. If not, you'll
need to run these commands to start HDFS:
```
vagrant ssh
sudo su hadoop
start-dfs.sh
```
Later, if you want to shut it down, just run `stop-dfs.sh`.

Now, as the `analytics` user, we need to load a log file to test with. Run this
command which will load `tracking.log-20150101-123456789`:
```
hdfs dfs -put ~/log_files/dummy/ /test_input
```

Next, run these two commands to process this log file and store the results in
MySQL:
```
cd ~/apps/pipeline
launch-task AnswerDistributionToMySQLTaskWorkflow --local-scheduler --remote-log-level DEBUG --include *tracking.log* --src hdfs://localhost:9000/test_input --dest hdfs://localhost:9000/test_answer_dist --name test_task --n-reduce-tasks 3
```

Note:
* If this seems stuck, it's likely due to MySQL being up to its usual antics,
  and an unpatched version of luigi being used. Press ctrl-c to stop it, then
  run `vagrant provision` on your host, and it will patch luigi [again] and
  remove any potentially problematic copies of luigi that may have shown up.
* If this fails with `IndexError: list index out of range`, run
  `vagrant provision` on your host, and it will patch luigi [again] to fix that.
* If this fails with "ProgrammingError: 1054 (42S22): Unknown column
  'answer_value_numeric' in 'field list'", it's due to an inconsistency between
  the pipeline and the data API. To workaround this, run this command:
  ```
  mysql -u root analytics --execute="ALTER TABLE answer_distribution ADD answer_value_numeric DOUBLE;"
  ```

Now, to check if the task worked, go to
http://192.168.33.11:50070/explorer.html#/test_answer_dist . You should see two
folders listed.

Now run:
```
mysql -u root analytics --execute="SELECT COUNT(*) FROM answer_distribution;"
```

If the pipeline task ran successfully, this should show a count of `2`.

Then, run the API server (see "Usage" above), and open your browser and go to
http://192.168.33.11:9001/docs/#!/api/Problem_Response_Answer_Distribution .
Enter `i4x://edX/DemoX-S/problem/a58470ee54cc49ecb2bb7c1b1c0ab43a` as the
`problem_id` (this is based on the dummy log file in
`/home/analytics/log_files/dummy`). Click "Try it out!" and ensure a result is
displayed.


Testing the pipeline (Database Imports)
---------------------------------------
Once that's working, we can try a database pipeline task.

Make sure the LMS devstack is running in on the same host and was configured as
described earlier in "LMS Setup" (so the pipeline can connect to its MySQL DB).

Run these commands to kick off the task:
```
cd ~/apps/pipeline
launch-task ImportAllDatabaseTablesTask --local-scheduler
```

If that completed successfully, you should be able to see the data stored in
Hive, using these commands:
```
$ hive
hive> show tables;
OK
auth_user
auth_userprofile
student_courseenrollment
Time taken: 0.952 seconds, Fetched: 3 row(s)
hive> SELECT * FROM auth_user;
```
You should now see a list of all the users that existed on the LMS system at the
time the `ImportAllDatabaseTablesTask` ran:
```
1 honor 2015-06-29 19:50:00 2014-11-19 04:06:46 true  false false honor@example.com 2015-07-05
2 audit 2014-11-19 04:06:49 2014-11-19 04:06:49 true  false false audit@example.com 2015-07-05
3 verified  2015-06-25 19:06:35 2014-11-19 04:06:52 true  false false verified@example.com  2015-07-05
4 staff 2015-07-03 19:17:16 2014-11-19 04:06:54 true  true  true  staff@example.com 2015-07-05
```
