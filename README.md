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

(Note it may take quite a while to provision the devstack at first - about 7
minutes for "Install required packages" and 20 minutes total. If you think
the provisioner might be hung, just `vagrant ssh` in different tab and run
`htop || top` to see what's running.)


Usage
-----

To do stuff, run `vagrant ssh` and then `sudo su analytics` to run commands.
You'll find all the apps in the `/home/analytics/apps` folder. Each app has
its own virtualenv in `/home/analytics/venvs/xxxxxx`, which will be
automagically activated for you when you `cd`, e.g. `cd ~/apps/pipeline`.

Ports are *not* forwarded, so you cannot access the apps via localhost:9000
(too prone to conflicts, with e.g. edX platform devstack). Instead, the
analytics devstack virtual box has the IP '192.168.33.11' so just connect
to that. e.g. On your host computer, go to http://192.168.33.11:9000/

### To start the data API ###
Run this command as the `analytics` user:
```
cd ~/apps/data-api/ && ./manage.py runserver 0.0.0.0:9001
```
Access it at http://192.168.33.11:9001/

### To start the dashboard ###
First, ensure the API server is running. Then, as the `analytics` user:
```
cd ~/apps/dashboard/ && make develop migrate && ./manage.py runserver 0.0.0.0:9000
```
Access it at http://192.168.33.11:9000/

To be able to sign into dashboard, the LMS must be running in its own
vagrant devstack on the same host. Configure this setup as follows:
* First, on your edx-platform devstack, edit `lms/envs/private.py` and add:
  ```
  OAUTH_OIDC_ISSUER = 'http://192.168.33.10:8000/oauth2'
  ```
* Next, on the edx-platform devstack, go to /admin/oauth2/client/2/ and add
  a new client with URL `http://192.168.33.11:9000/` and redirect URI
  `http://192.168.33.11:9000/complete/edx-oidc/`. Client type confidential.
* On the analytics devstack, edit
  `~/apps/dashboard/analytics_dashboard/settings/local.py` and set the values of
  `SOCIAL_AUTH_EDX_OIDC_KEY` and `SOCIAL_AUTH_EDX_OIDC_SECRET`. The LMS must
  also be running on a devstack on the same host.


Tests
-----
```
vagrant up && vagrant ssh
sudo su analytics
cd ~/apps/pipeline/; make test
cd ~/apps/data-api/; make validate
cd ~/apps/data-api-client/; make test
cd ~/apps/dashboard/; make requirements.js; ./node_modules/.bin/r.js -o build.js; make validate
```

Testing the pipeline
--------------------
To test the pipeline, run these commands as the `analytics` user:
```
cd ~/apps/pipeline/
launch-task AnswerDistributionToMySQLTaskWorkflow --local-scheduler --remote-log-level DEBUG --include *tracking.log* --src ~/log_files/dummy --dest /tmp/answer_dist --name test_task
```

Note: If this fails with "ProgrammingError: 1054 (42S22): Unknown column
'answer_value_numeric' in 'field list'", it's due to an inconsistency between
the pipeline and the data API. To workaround this, run this command:
```
mysql -u root analytics --execute="ALTER TABLE answer_distribution ADD answer_value_numeric DOUBLE;"
```

Now, to check if the task worked, run:
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
