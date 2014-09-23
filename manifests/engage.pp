class tomcat7_rhel::engage (
  $http_port = 80,
  $https_port = 443,
  $tomcat_port = 8080,
  $tomcats_port = 8443,
  $tomcat_user = "tomcat",
  $jvm_envs = "-server -Xms512m -Xmx3072m -XX:MaxPermSize=512m",
  $engage_version = "1.1.0",
  $platform_snapshot = "20140923.034702-4",
  $static_version = "1.1.0",
  $static_snapshot = "20140923.034729-4",
  $database_server,
  $database_instance,
  $database_uid,
  $database_pwd,
  $database_show_sql = false,
  $artifactory_uid,
  $artifactory_pwd
  ) {

  include tomcat7_rhel
  include wget

  $application_root = "/var/lib"
  $application_name = "engage_v1"
  $application_dir = "$application_root/$application_name"
  $application_cache = "/var/cache/$application_name"
  $catalina_home = "/usr/share/tomcat7"

  $war_dir = "$application_dir/webapps/ROOT"
  $war_file = "$application_cache/ROOT.war"

  $static_dir = "$application_dir/webapps/static"
  $static_file = "$application_cache/static.war"

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
  
  file { "$application_cache":
    ensure => directory
  } 
  
  if $platform_snapshot == '' {
    $engage_war = "riskflo-engage-web-$engage_version.war"
    $engage_url = "http://artifactory.riskflo.net.au/repository/libs-release-local/com/riskflo/engage/riskflo-engage-web/$engage_version/riskflo-engage-web-$engage_version.war"
  } else {
    $engage_war = "riskflo-engage-web-${engage_version}-${platform_snapshot}.war"
    $engage_url = "http://artifactory.riskflo.net.au/repository/libs-snapshot-local/com/riskflo/engage/riskflo-engage-web/${engage_version}-SNAPSHOT/riskflo-engage-web-${engage_version}-${platform_snapshot}.war"
  }
  
  wget::fetch { "$engage_url":
    user        => "$artifactory_uid",
    password    => "$artifactory_pwd",
    destination => "${war_file}",
    cache_dir   => "$application_cache",
    cache_file  => "$engage_war",
    execuser    => "$tomcat_user",
    notify      => [ Exec["unpack_engage"], Service["$application_name"]],
    verbose     => false
  } 
  
  if $static_snapshot == '' {
    $static_war = "riskflo-engage-static-${static_version}.war"
    $static_url = "http://artifactory.riskflo.net.au/repository/libs-release-local/com/riskflo/engage/riskflo-engage-static/${static_version}/riskflo-engage-static-${static_version}.war"
  } else {
    $static_war = "riskflo-engage-static-${static_version}-${static_snapshot}.war"
    $static_url = "http://artifactory.riskflo.net.au/repository/libs-snapshot-local/com/riskflo/engage/riskflo-engage-static/${static_version}-SNAPSHOT/riskflo-engage-static-${static_version}-${static_snapshot}.war"
  }
  
  wget::fetch { "$static_url":
    user        => "$artifactory_uid",
    password    => "$artifactory_pwd",
    destination => "$static_file",
    cache_dir   => "$application_cache",
    cache_file  => "$static_war",
    execuser    => "$tomcat_user",
    verbose     => false,
    notify      => [ Exec["unpack_static"], Service["$application_name"]],
  }

  exec {"unpack_engage":
    command => "/bin/rm -Rf ${war_dir}; /bin/mkdir -p ${war_dir}; /usr/bin/unzip -o -q ${application_cache}/${engage_war} -d ${war_dir}; /usr/bin/find ${war_dir}/WEB-INF/lib/*classes.jar -type f -exec rm {} \;",
    refreshonly => true,
    user => "$tomcat_user",
    subscribe => [Wget::Fetch["$engage_url"]],
    notify => [ File["${war_dir}/WEB-INF/classes/META-INF/spring/engage-database.properties"], Service["$application_name"] ]
  } 
  
  exec {"unpack_static":
    command => "/bin/rm -Rf ${static_dir}; /bin/mkdir -p ${static_dir}; /usr/bin/unzip -o -q ${application_cache}/${static_war} -d ${static_dir};",
    refreshonly => true,
    user => "$tomcat_user",
    subscribe => [Wget::Fetch["$static_url"]],
    notify => [ Service["$application_name"]]
  } 
  
  file { "${war_dir}/WEB-INF/classes/META-INF/spring/database.properties":
    content => template("tomcat7_rhel/database.properties.erb"),
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,    
    subscribe => [ Exec["unpack_engage"]],
    notify  => Service["$application_name"],
  } 
  
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
}
