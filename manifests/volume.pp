define luks::volume (
  $ensure  = 'present',
  $device  = '',
  $key     = '',
  $onboot  = false,
) {



  case $ensure {
    'present': {

      if ! $device  { fail('Must pass $device when setting ensure => present') }
      if ! $key     { fail('Must pass $key when setting ensure => present') }

      case $onboot {
        # create keyfile and autoopen on boot (works for binary and ascii keys)
        'auto': {

          $keyfile = "/etc/luks/${name}.key"

          file { $keyfile:
            ensure  => 'present',
            owner   => 'root',
            group   => 'root',
            mode    => '0640',
            content => $key,
          }

          exec { "luks-${name}":
            command => "cryptsetup luksOpen --key-file ${keyfile} ${device} ${name}",
            creates => "/dev/mapper/${name}",
            require => File[$keyfile],
          }

          # see here for while this isn't working (instead we have to use the file_line below):
          # http://www.redhat.com/archives/augeas-devel/2009-June/msg00086.html
          # "(defnode doesn't work with the hosts lens, since it creates hosts/N/ rather than hosts[N]."
          #
          #      augeas { "luks-${name}":
          #        context => '/files/etc/crypttab',
          #        changes => [
          #          "defnode target *[target = '${name}'][device = '${device}'][password = '${keyfile}'] ${name}",
          #          "clear \$target",
          #          "set \$target/target ${name}",
          #          "set \$target/device ${device}",
          #          "set \$target/password ${keyfile}",
          #          "set \$target/opt luks",
          #        ],
          #        onlyif => "match *[target = '${name}'][device = '${device}'][password = '${keyfile}'] size == 0",
          #      }

          file_line { "luks-${name}":
            ensure => present,
            path   => '/etc/crypttab',
            match  => "^${name} .*",
            line   => "${name} ${device} ${keyfile} luks",
          }

        } # end $onboot = auto


        # prompt on boot for key, or let puppet open the device (works for ascii keys only)
        'manual': {
          file { "/etc/luks/${name}.key":
            ensure => 'absent'
          }

          exec { "luks-${name}":
            environment => "KEY=${key}",
            command => "echo \"\$KEY\" | cryptsetup luksOpen ${device} ${name}",
            creates => "/dev/mapper/${name}",
          }

          file_line { "luks-${name}":
            ensure => present,
            path   => '/etc/crypttab',
            match  => "^${name} .*",
            line   => "${name} ${device} none luks",
          }

        } # end $onboot = manual


        # do not open on boot, but let puppet open the device (works for ascii keys only)
        default: {
          file { "/etc/luks/${name}.key":
            ensure => 'absent'
          }

          exec { "luks-${name}":
            environment => "KEY=${key}",
            command => "echo \"\$KEY\" | cryptsetup luksOpen ${device} ${name}",
            creates => "/dev/mapper/${name}",
          }

          file_line { "luks-${name}":
            ensure => absent,
            path   => '/etc/crypttab',
            match  => "^${name} .*",
            line   => "${name} ",
          }

        } # end default

      } # end case $onboot



    } # end present

    'absent': {
      exec { "luks-${name}":
        command => "cryptsetup luksClose ${name}",
        onlyif  => "ls /dev/mapper/${name}",
      }

      file { "/etc/luks/${name}.key":
        ensure => 'absent'
      }

      file_line { "luks-${name}":
        ensure => absent,
        path   => '/etc/crypttab',
        match  => "^${name} .*",
      }
    } # end absent

    default: { fail("${ensure} is no valid parameter for luks::volume.") }

  } # end case $ensure



}
