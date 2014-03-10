A useful boilerplate that uses [Vagrant](http://www.vagrantup.com/) and [Puppet](http://puppetlabs.com/) to setup your development server and create your [Django](http://www.djangoproject.com/) 1.6 project. You'll have a development environment up and running in no time.

Includes
--------
* Debian 7.4
* Nginx
* Python 2.7
* Virtualenv
 * Django 1.6.2
 * django-celery
 * django-compressor
 * django-debug-toolbar
 * Fabric
 * South
 * psycopg2
 * Gunicorn
* Postgrsql 9.3
* Suprvisor

Installation
------------

* you can fork the repository and use it as your project repo, clone it or just dowload the zip and unpack in you existing project.
* change the settings from **data/config.yaml** to customize your app. Create a folder for the **synced_folder** option. We user *src* as default, but you can custumize it as you wish. It doesn't even have to be in the current directory.
* start your virtual machine:
```
$ vagrant up
```
* go get a coffee and wait until the VM is up and provisioned
* after the provision process is done you will have the DJango project created in you synced_folder based on [hipwerk/django-skel](https://github.com/hipwerk/django-skel) repository
* edit the DB connection params from the Django settings
```
$ vagrant ssh
$ cd /path/to/your/django/app
$ python manage.py syncdb
$ python manage.py migrate
```
* now you just have to add a new line in your hosts file to map the configured virtual host and IP address
* that's it!
