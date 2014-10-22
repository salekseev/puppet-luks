class luks::install {

  package { 'cryptsetup':
    ensure => 'present',
  }

}
