class tomcat7_rhel::discovery (
  $http_port = 80,
  $https_port = 443,
  $tomcat_port = 8080,
  $tomcats_port = 8443,
  $tomcat_user = "tomcat",
  $jvm_envs = "-server -Xms512m -Xmx3072m -XX:MaxPermSize=512m",
  $discovery_version = "2.0.9",
  $platform_snapshot = "20140619.072517-23",
  $static_version = "2.0.9",
  $static_snapshot = "20140619.071039-26",
  $database_server,
  $database_instance,
  $database_uid,
  $database_pwd,
  $artifactory_uid,
  $artifactory_pwd
  ) {

  include tomcat7_rhel
  include wget

  $application_root = "/var/lib"
  $application_name = "discovery"
  $application_dir = "$application_root/$application_name"
  $application_cache = "/var/cache/$application_name"
  $catalina_home = "/usr/share/tomcat7"

  file { "/etc/init.d/tomcat7":
    ensure  => file,
    source  => "puppet:///modules/tomcat7_rhel/etc/init.d/tomcat7",
    require => Package['tomcat7']
  }

  tomcat7_rhel::tomcat_application { "$application_name":
    application_root => $application_root,
    tomcat_user      => $tomcat_user,
    tomcat_port      => $tomcat_port,
    jvm_envs         => $jvm_envs,
    tomcat_manager   => false,
    require          => Package['tomcat7']
  }

  file { "$catalina_home/.keystore":
    source  => "puppet:///modules/tomcat7_rhel/.keystore",
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,
    notify  => Service["$application_name"],
    require => File["/etc/sysconfig/$application_name"] 
  }

  file {"$catalina_home/conf/web.xml":
    content => template("tomcat7_rhel/web.xml.erb"),
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,
    notify  => Service["$application_name"],
    require => Package['tomcat7']
  }
  
  if $platform_snapshot = '' {
    $discovery_war = "http://artifactory.riskflo.net.au/repository/libs-release-local/com/riskflo/discovery/riskflo-platform-web/$discovery_version/riskflo-platform-web-$discovery_version.war"
  } else {
    $discovery_war = "http://artifactory.riskflo.net.au/repository/libs-snapshot-local/com/riskflo/discovery/riskflo-platform-web/${discovery_version}-SNAPSHOT/riskflo-platform-web-${discovery_version}-${platform_snapshot}.war"
  }
  
  if $static_snapshot = '' {
    $static_war = "http://artifactory.riskflo.net.au/repository/libs-release-local/com/riskflo/discovery/riskflo-static-web/${static_version}/riskflo-static-web-${static_version}.war"
  } else {
    $static_war = "http://artifactory.riskflo.net.au/repository/libs-snapshot-local/com/riskflo/discovery/riskflo-static-web/${static_version}-SNAPSHOT/riskflo-static-web-${static_version}-${static_snapshot}.war"
  }
  
  wget::fetch { '$discovery_war':
    user        => '$artifactory_uid',
    password    => '$artifactory_pwd',
    destination => '$application_dir/webapps/ROOT.war',
    cache_dir   => '$application_cache',
  }

  wget::fetch { '$static_war':
    user        => '$artifactory_uid',
    password    => '$artifactory_pwd',
    destination => '$application_dir/webapps/static.war',
    cache_dir   => '$application_cache',
  }

  file { "$application_dir/webapps/ROOT.war":
    ensure  => file, 
    # source  => "puppet:///modules/tomcat7_rhel/riskflo-platform-web-$discovery_version-$platform_snapshot.war",
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,
    notify  => [ Exec["unpack_war"], Service["$application_name"]],
    #require => File["$application_dir/webapps"]
    require => Wget::Fetch['$discovery_war']
  }
  
  file { "$application_dir/webapps/static.war":
    ensure  => file, 
    #source  => "puppet:///modules/tomcat7_rhel/riskflo-static-web-$discovery_version-$static_snapshot.war",
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,
    notify  => Service["$application_name"],
    #require => File["$application_dir/webapps"]
    require => Wget::Fetch['$static_war']
  }
 
  file { "$application_dir/webapps/ROOT/WEB-INF/classes/META-INF/spring/discovery-database.properties":
    content => template("tomcat7_rhel/discovery-database.properties.erb"),
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,    
    notify  => Service["$application_name"],
    require => [ File["$application_dir/webapps/ROOT.war"], Exec["unpack_war"]]
  }
  
  #file { "$application_dir/webapps/ROOT/WEB-INF/lib/":
  #  ensure => absent
  #}

  firewall { '100 Tomcat7 port redirect for http':
    chain    => 'PREROUTING',
    jump     => 'REDIRECT',
    proto    => 'tcp',
    dport    => $http_port,
    toports  => $tomcat_port,
    table    => 'nat'
  }
  
  firewall { '101 Tomcat7 port redirect for https':
    chain    => 'PREROUTING',
    jump     => 'REDIRECT',
    proto    => 'tcp',
    dport    => $https_port,
    toports  => $tomcats_port,
    table    => 'nat'
  }

  exec {"unpack_war":
    command => "/bin/mkdir -p $application_dir/webapps/ROOT; /usr/bin/unzip -o -q $application_dir/webapps/ROOT.war -d $application_dir/webapps/ROOT",
    creates => "$application_dir/webapps/ROOT",
    refreshonly => true,
    user => "$tomcat_user",
  }
}
