include '::ntp'
include '::rabbitmq'

class djangoapp::homesetup (
  $username = 'vagrant'
) {
  Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }
  group { 'puppet':   ensure => present }
  group { 'www-data': ensure => present }

  user { $username:
    shell  => '/bin/bash',
    home   => "/home/${username}",
    ensure => present
  }

  user { ['nginx', 'httpd', 'www-data']:
    shell  => '/bin/bash',
    ensure => present,
    groups => 'www-data',
    require => Group['www-data'],
  }

  file { "/home/${username}":
      ensure => directory,
      owner  => $username,
  }

  # copy dot files to ssh user's home directory
  exec { 'dotfiles':
    cwd     => "/home/${username}",
    command => "cp -r /vagrant/data/files/dot/.[a-zA-Z0-9]* /home/${username}/ \
                && chown -R ${username} /home/${ssh_username}/.[a-zA-Z0-9]* \
                && cp -r /vagrant/data/files/dot/.[a-zA-Z0-9]* /root/",
    onlyif  => 'test -d /vagrant/data/files/dot',
    returns => [0, 1],
    require => User[$username],
  }
}

class djangoapp::aptsetup {
  include apt::backports

  add_dotdeb { 'packages.dotdeb.org': release => $lsbdistcodename }

  $server_lsbdistcodename = downcase($lsbdistcodename)

  apt::force { 'git':
    release => "${server_lsbdistcodename}-backports",
    timeout => 60
  }

  define add_dotdeb ($release){
     apt::source { $name:
      location          => 'http://packages.dotdeb.org',
      release           => $release,
      repos             => 'all',
      required_packages => 'debian-keyring debian-archive-keyring',
      key               => '89DF5277',
      key_server        => 'keys.gnupg.net',
      include_src       => true
    }
  }
}

class djangoapp::rabbitmqSetup {
   class { 'rabbitmq':
     port => '5672'
   }
}


class djangoapp::nginxsetup (
  $app_name = 'djangoapp',
  $app_path = undef,
  $app_host = undef,
  $app_static_path = undef,
  $app_media_path = undef
) {
  file { "/etc/nginx/conf.d/${app_name}.conf":
      ensure => file,
      mode   => 644,
      content => template("/vagrant/data/files/templates/nginx.django.erb"),
      group  => 'root',
      owner  => 'root',
      require => Package['nginx'],
      notify    => Service['nginx'],
  }
}

class djangoapp::pgsetup (
  $root_password = undef,
  $user_group = 'postgres',
  $databases = undef
) {

  class { 'postgresql::globals':
    manage_package_repo => true,
    version             => '9.3',
  }

  if $root_password != undef {
    group { $user_group:
        ensure => present,
    }

    class { 'postgresql::server':
      postgres_password => $root_password,
      require           => Group[$user_group],
      ip_mask_deny_postgres_user => '0.0.0.0/32',
      ip_mask_allow_all_users    => '0.0.0.0/0',
      listen_addresses           => '*'
    }

    if is_hash($databases) and count($databases) > 0 {
      create_resources(postgresql_db, $databases)
    }
  }

  class { 'postgresql::lib::devel':
    package_ensure => present
  }

  define postgresql_db (
    $user,
    $password,
    $grant,
    $sql_file = false
  ) {
    if $name == '' or $user == '' or $password == '' or $grant == '' {
      fail( 'PostgreSQL DB requires that name, user, password and grant be set. Please check your settings!' )
    }

    postgresql::server::db { $name:
      user     => $user,
      password => $password,
      grant    => $grant
    }

    postgresql::server::role { $user:
      createdb => true,
      login => true,
      password_hash => postgresql_password($user, $password),
    }

    if $sql_file {
      $table = "${name}.*"

      exec{ "${name}-import":
        command     => "psql ${name} < ${sql_file}",
        logoutput   => true,
        refreshonly => $refresh,
        require     => Postgresql::Server::Db[$name],
        onlyif      => "test -f ${sql_file}"
      }
    }
  }
}

class djangoapp::virtualEnvSetup (
  $virtual_env_path = undef,
  $owner = undef,
  $group = undef,
  $requirements_file = undef,
  $ssh_user = 'vagrant'
) {

#  file { 'venv-folder':
#      path        => "${$virtual_env_path}",
#      ensure      =>  directory,
#      owner       => $owner,
#      group       => $group,
#  }

  python::virtualenv { "${$virtual_env_path}":
    ensure       => present,
    version      => 'system',
    owner        => 'vagrant',
    group        => 'vagrant',
    cwd          => "${$virtual_env_path}",
    timeout      => 0,
    require      => [Class['python'], Class['postgresql::lib::devel']]
  }

  python::requirements { 'python-requirements':
    requirements => $requirements_file,
    virtualenv => "${$virtual_env_path}",
    owner        => $owner,
    group        => $group,
    forceupdate  => true,
    require => Python::Virtualenv["${$virtual_env_path}"],
  }

  file_line { 'activate_venv':
    path    => "/home/${ssh_user}/.bashrc",
    line    => "source ${$virtual_env_path}/bin/activate"
  }
}

class djangoapp::gunicornSetup(
  $app_name = 'djangoapp',
  $app_path = undef,
  $owner = 'vagrant',
  $group = 'www-data',
  $virtual_env_path = undef
) {

  package { 'supervisor':
      provider => apt,
      ensure   => latest,
      require => Class["apt::update"],
  }

  file { 'gunicorn-config':
      path => "/etc/supervisor/conf.d/${app_name}.conf",
      ensure => file,
      mode   => 644,
      content => template("/vagrant/data/files/templates/supervisor.erb"),
      group  => 'root',
      owner  => 'root',
      require => Package['supervisor'],
  }

  file { "${$virtual_env_path}/log":
      ensure => directory,
      mode   => 775,
      owner  => $user,
      group  => $group,
  }

  service { 'supervisor':
    ensure    => running,
    enable    => true,
    subscribe => File['gunicorn-config'],
    require => [Package['supervisor'], Python::Virtualenv["${$virtual_env_path}"], Python::Requirements['python-requirements'], Package['nginx']],
  }
}

class djangoapp::initApp(
  $app_path = undef,
  $app_name = 'djangoapp',
  $user = 'vagrant',
  $group = 'www-data',
  $virtual_env_path = undef
) {

  exec { "django-create-project":
    command => "${virtual_env_path}/bin/python ${virtual_env_path}/bin/django-admin.py startproject --template=https://github.com/hipwerk/django-skel/zipball/master ${app_name} ${app_path}",
    cwd     => $app_path,
    creates => "${app_path}/${app_name}",
    path    => ["/usr/bin", "/usr/sbin"],
    user  => $user,
    group  => $group,
  }

  file { 'gunicorn-config-file':
      path => "${app_path}/gunicorn.py",
      ensure => file,
      mode   => 644,
      content => template("/vagrant/data/files/templates/gunicorn.config.erb"),
      group  => $user,
      owner  => $group,
      require => Exec["django-create-project"],
  }
}

$app_values = hiera('webapp', false)
$python_values = hiera('python', false)
$server_values = hiera('server', false)
$postgresql_values = hiera('postgresql', false)

$virtual_env_path = $python_values['virtualenv']['path']
$requirements_file = $python_values['virtualenv']['requirements']

class { 'djangoapp::homesetup': username => $::ssh_username }
class { 'djangoapp::aptsetup':}
class { 'nginx': }

class { 'elasticsearch':
  manage_repo  => true,
  repo_version => '1.3',
  java_install => true
}

elasticsearch::instance { 'es-01': }


class { 'djangoapp::pgsetup':
  root_password => $postgresql_values['root_password'],
  user_group => $postgresql_values['user_group'],
  databases => $postgresql_values['databases'],
}
class { 'python': dev => true, virtualenv => true, pip => true, gunicorn => false,}

class { 'djangoapp::virtualEnvSetup':
  virtual_env_path => $virtual_env_path,
  owner => $::ssh_username,
  group => $::ssh_username,
  requirements_file => $requirements_file,
  ssh_user => $::ssh_username,
  require => Class['python'],
}

class { 'djangoapp::initApp':
  app_name => $app_values['name'],
  app_path => $app_values['path'],
  user => $app_values['owner'],
  group => $app_values['group'],
  virtual_env_path => $virtual_env_path,
  require => Class['djangoapp::virtualEnvSetup'],
}

class { 'djangoapp::gunicornSetup':
  app_name => $app_values['name'],
  app_path => $app_values['path'],
  owner => $app_values['owner'],
  group => $app_values['group'],
  virtual_env_path => $virtual_env_path,
  require => Class['djangoapp::initApp'],
}

class { 'djangoapp::nginxsetup':
  app_name => $app_values['name'],
  app_host => $app_values['hostname'],
  app_static_path => $app_values['static_path'],
  app_media_path => $app_values['media_path'],
  require => Class['djangoapp::gunicornSetup'],
}

#
if !empty($server_values['packages']) {
  ensure_packages( $server_values['packages'] )
}
