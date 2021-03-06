# == Class: psp::hpsnmp
#
# This class handles installation of the HP Proliant Support Pack SNMP Agent.
#
# === Parameters:
#
# [*cmalocalhostrwcommstr*]
#   Community string for Compaq Management Agents to talk to the SNMP server.
#   Default: none
#
# [*ensure*]
#   Ensure if present or absent.
#   Default: present
#
# [*autoupgrade*]
#   Upgrade package automatically, if there is a newer version.
#   Default: false
#
# [*service_ensure*]
#   Ensure if service is running or stopped.
#   Default: running
#
# [*service_enable*]
#   Start service at boot.
#   Default: true
#
# === Actions:
#
# Installs and configures the HP SNMP Agents.
# Installs and configures the SNMP server to work with the HP SNMP Agents.
#
# === Requires:
#
# $cmalocalhostrwcommstr
# Class['psp']
# Class['psp::snmp']
# Class['psp::hphealth']
#
# === Sample Usage:
#
#   class { 'psp::hpsnmp': }
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2012 Mike Arnold, unless otherwise noted.
#
class psp::hpsnmp (
  $cmalocalhostrwcommstr,
  $ensure         = 'present',
  $autoupgrade    = false,
  $service_ensure = 'running',
  $service_enable = true
) inherits psp::params {

  case $ensure {
    /(present)/: {
      if $autoupgrade == true {
        $package_ensure = 'latest'
      } else {
        $package_ensure = 'present'
      }
      $file_ensure = 'present'
      if $service_ensure in [ running, stopped ] {
        $service_ensure_real = $service_ensure
        $service_enable_real = $service_enable
      } else {
        fail('service_ensure parameter must be running or stopped')
      }
    }
    /(absent)/: {
      $package_ensure = 'absent'
      $file_ensure = 'absent'
      $service_ensure_real = 'stopped'
      $service_enable_real = false
    }
    default: {
      fail('ensure parameter must be present or absent')
    }
  }

  case $::manufacturer {
    'HP': {
      include psp::snmp
      Class['psp'] -> Class['psp::snmp'] -> Class['psp::hphealth'] ->
      Class['psp::hpsnmp']

      realize Group['hpsmh']
      realize User['hpsmh']

      package { 'hp-snmp-agents':
        ensure   => $package_ensure,
#        require  => Package['hphealth'],
        require  => Package['snmpd'],
      }

      file { 'snmpd.conf-HP':
        ensure  => $file_ensure,
        mode    => '0660',
        owner   => 'root',
        group   => 'hpsmh',
        path    => '/etc/snmp/snmpd.conf-HP',
        content => template('snmp/snmpd.conf.erb'),
        require => Package['snmpd'],
        notify  => Exec['copy_snmpd.conf-HP'],
      }

      exec { 'copy_snmpd.conf-HP':
        command     => '/bin/cp -f /etc/snmp/snmpd.conf-HP /etc/snmp/snmpd.conf',
        require     => File['snmpd.conf-HP'],
        notify      => Exec['hpsnmpconfig'],
        refreshonly => true,
      }

      exec { 'hpsnmpconfig':
        command     => '/sbin/hpsnmpconfig',
        environment => [
          'CMASILENT=yes',
          "CMALOCALHOSTRWCOMMSTR=${cmalocalhostrwcommstr}",
#          'CMASYSCONTACT=',
#          'CMASYSLOCATION=',
#          'CMAMGMTSTATIONROCOMMSTR=',
#          'CMAMGMTSTATIONROIPORDNS=',
#          'CMATRAPDESTINATIONCOMMSTR=',
#          'CMATRAPDESTINATIONIPORDNS='
        ],
#        subscribe => File['snmpd.conf'],
#        creates => '/etc/hp-snmp-agents.conf',
        refreshonly => true,
        require     => Package['hp-snmp-agents'],
        before      => Service['hp-snmp-agents'],
        notify      => Service['snmpd'],
      }

      file { 'cma.conf':
        ensure  => $file_ensure,
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        path    => '/opt/hp/hp-snmp-agents/cma.conf',
        source  => [
          "puppet:///modules/psp/cma.conf-${::fqdn}",
          'puppet:///modules/psp/cma.conf',
        ],
        require => Package['hp-snmp-agents'],
        notify  => Service['hp-snmp-agents'],
      }

      service { 'hp-snmp-agents':
        ensure     => $service_ensure_real,
        enable     => $service_enable_real,
        hasrestart => true,
        hasstatus  => true,
        require    => Package['hp-snmp-agents'],
      }
    }
    # If we are not on HP hardware, do not do anything.
    default: { }
  }
}
