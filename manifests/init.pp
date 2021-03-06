# = Class: composer
#
# == Parameters:
#
# [*target_dir*]
#   Where to install the composer executable.
#
# [*command_name*]
#   The name of the composer executable.
#
# [*user*]
#   The owner of the composer executable.
#
# [*auto_update*]
#   Whether to run `composer self-update`.
#
# [*version*]
#   Custom composer version.
#
# [*group*]
#   Owner group of the composer executable.
#
# [*download_timeout*]
#   The timeout of the download for wget.
#
# == Example:
#
#   include composer
#
#   class { 'composer':
#     'target_dir'   => '/usr/local/bin',
#     'user'         => 'root',
#     'command_name' => 'composer',
#     'auto_update'  => true
#   }
#
class composer (
  $target_dir       = $::composer::params::target_dir,
  $command_name     = $::composer::params::command_name,
  $user             = $::composer::params::user,
  $auto_update      = false,
  $version          = undef,
  $group            = undef,
  $download_timeout = '0',
  $build_deps       = true,
) inherits ::composer::params {
  validate_string($target_dir)
  validate_string($command_name)
  validate_string($user)
  validate_bool($auto_update)
  validate_string($version)
  validate_string($group)
  validate_bool($build_deps)

  include composer::params

  $target = $version ? {
    undef   => $::composer::params::phar_location,
    default => "https://getcomposer.org/download/${version}/composer.phar"
  }

  $composer_full_path = "${target_dir}/${command_name}"
  
  case $::kernel {
    'Darwin': {
      $download_command = "/usr/bin/curl --insecure -o ${composer_full_path} ${target}"
      $download_require = undef
      $test_exec = '/bin/test'
    }
    default: {
      $download_command = "/usr/bin/wget --no-check-certificate -O ${composer_full_path} ${target}"
      $download_require = Package['wget']
      $test_exec = '/usr/bin/test'
      
      if $build_deps {
        ensure_packages(['wget'])
      }
    }
  }
  
  $unless = $version ? {
    undef   => "${test_exec} -f ${composer_full_path}",
    default => "${test_exec} -f ${composer_full_path} && ${composer_full_path} -V |grep -q ${version}"
  }

  exec { 'composer-install':
    command     => "${download_command}",
    environment => [ "COMPOSER_HOME=${target_dir}" ],
    user        => $user,
    unless      => $unless,
    timeout     => $download_timeout,
    require     => $download_require,
  }

  file { "${target_dir}/${command_name}":
    ensure  => file,
    owner   => $user,
    mode    => '0755',
    group   => $group,
    require => Exec['composer-install'],
  }

  if $auto_update {
    exec { 'composer-update':
      command     => "${composer_full_path} self-update",
      environment => [ "COMPOSER_HOME=${target_dir}" ],
      user        => $user,
      require     => File["${target_dir}/${command_name}"],
    }
  }
}
