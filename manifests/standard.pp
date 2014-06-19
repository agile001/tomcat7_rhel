class tomcat7_rhel::standard (
  $http_port = 80,
  $https_port = 443,
  $tomcat_port = 8080,
  $tomcats_port = 8443,
  $tomcat_user = "tomcat",
  $jvm_envs = "-server -Xms512m -Xmx3072m -XX:MaxPermSize=512m",
  $engage_version = "1.0.9",
  $database_server,
  $database_instance,
  $database_uid,
  $database_pwd,
  $artifactory_uid,
  $artifactory_pwd
  ) {

  include tomcat7_rhel

  $application_root = "/var/lib"
  $application_name = "engage_v1"
  $application_dir = "$application_root/$application_name"
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
  
  file { "$application_dir/webapps/ROOT.war":
    ensure  => file, 
    source  => "puppet:///modules/tomcat7_rhel/riskflo-engage-web-$engage_version.war",
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,
    notify  => [ Exec["unpack_war"], Service["$application_name"]],
    require => File["$application_dir/webapps"]
  }
  
  file { "$application_dir/webapps/static.war":
    ensure  => file, 
    source  => "puppet:///modules/tomcat7_rhel/riskflo-engage-static-$engage_version.war",
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,
    notify  => Service["$application_name"],
    require => File["$application_dir/webapps"]
  }
 
  file { "$application_dir/webapps/ROOT/WEB-INF/classes/META-INF/spring/database.properties":
    content => template("tomcat7_rhel/database.properties.erb"),
    owner   => "$tomcat_user",
    group   => "$tomcat_user",
    mode    => 0644,    
    notify  => Service["$application_name"],
    require => [ File["$application_dir/webapps/ROOT.war"], Exec["unpack_war"]]
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

  exec {"unpack_war":
    command => "/bin/mkdir -p $application_dir/webapps/ROOT; /usr/bin/unzip -o -q $application_dir/webapps/ROOT.war -d $application_dir/webapps/ROOT",
    creates => "$application_dir/webapps/ROOT",
    refreshonly => true,
    user => "$tomcat_user",
  }
}
