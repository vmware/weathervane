#!/usr/bin/perl
# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Created by: Hal Rosenberg
#
# This script sets up Weathervane on Centos7
#
package AutoSetup;
use strict;

# Turn on auto flushing of output
BEGIN { $| = 1 }

sub runAndLog {
	my ( $fileout, $cmd ) = @_;
	print $fileout "COMMAND> $cmd\n";
	open( CMD, "$cmd 2>&1 |" ) || die "Couldn't run command $cmd: $!\n";
	while ( my $line = <CMD> ) {
		print $fileout $line;
	}
	close CMD;
}

sub setOS {

	if ( -e "/etc/centos-release" ) {
		my $release = `cat /etc/centos-release`;
		if ( $release =~ /release 7/ ) {
			return "centos7";
		}
		else {
			die "The only distribution currently supported by this script is Centos 7/\n";
		}
	}
	else {
		die "The only distribution currently supported by this script is Centos 7/\n";
	}
}

sub setServiceManager {
	my ($os) = @_;

	if ( $os eq "centos6" ) {
		return "init";
	}
	elsif ( $os eq "centos7" ) {
		return "systemd";
	}
	else {
		die "Unsupported OS $os\n";
	}
}

sub forceLicenseAccept {
	open( my $fileout, "/root/weathervane/Notice.txt" ) or die "Can't open file /root/weathervane/Notice.txt: $!\n";
	while (my $inline = <$fileout>) {
		print $inline;
	}
	
	print "Do you accept these terms and conditions (yes/no)? ";
	my $answer = <STDIN>;
	chomp($answer);
	$answer = lc($answer);
	while (($answer ne "yes") && ($answer ne "no")) {
		print "Please answer yes or no: ";
		$answer = <STDIN>;
		chomp($answer);
		$answer = lc($answer);
	}
	if ($answer eq "yes") {
		open (my $file, ">/root/weathervane/.accept-autosetup") or die "Can't create file .accept-autosetup: $!\n";
		close $file;
	} else {
		exit -1;		
	}
}

unless (-e "/root/weathervane/.accept-autosetup") {
	forceLicenseAccept();
}

my $cmdout;
my $fileout;
open( $fileout, ">autoSetup.log" ) or die "Can't open file autoSetup.log for writing: $!\n";

my $os             = setOS();

my $serviceManager = setServiceManager($os);

print "Performing autoSetup for a $os host.\n";
print $fileout "Performing autoSetup for a $os host.\n";
runAndLog( $fileout, "setenforce 0" );

print "Installing Java\n";
runAndLog( $fileout, "yum install -y java-1.8.0-openjdk" );
runAndLog( $fileout, "yum install -y java-1.8.0-openjdk-devel" );

print "Building Weathervane executables\n";
runAndLog( $fileout, "./gradlew clean release" );

print "Removing Network Manager if installed.\n";
print $fileout "Removing Network Manager if installed.\n";
runAndLog( $fileout, "systemctl disable NetworkManager" );
runAndLog( $fileout, "systemctl stop NetworkManager" );
runAndLog( $fileout, "yum remove -y NetworkManager" );
runAndLog( $fileout, "yum remove -y PackageKit" );

print "Configuring NICs\n";
print $fileout "Configuring NICs\n";
if ( $os eq "centos7" ) {
	runAndLog( $fileout, "chmod +x /etc/rc.d/rc.local" );
}

# find the name of the ethernet device(s), disable PEERDNS
# and set txqueuelen in rc.local
my @nicNames;
my $ifcfgTxt = `ifconfig -a`;
my @ifcfgLines = split( /\n/, $ifcfgTxt );
foreach my $line (@ifcfgLines) {
	if ( $line =~ /^(e.*):\s/ ) {
		print $fileout "Found nic: $1\n";
		push( @nicNames, $1 );
	}
}

foreach my $nic (@nicNames) {

	# Get the MAC address for the NIC and make sure it is correct
	# in the ifcfg file
	my $macString = `ethtool -P $nic`;
	if ( !( $macString =~ /Permanent\saddress:\s(.*)$/ ) ) {
		die "Couldn't get MAC address of NIC $nic using ethtool\n";
	}
	$macString = $1;

	open( my $ifcfgFile, "</etc/sysconfig/network-scripts/ifcfg-$nic" )
	  or die "Couldn't open /etc/sysconfig/network-scripts/ifcfg-$nic for reading: $!\n";
	open( my $newIfcfgFile, ">/tmp/ifcfg-$nic" )
	  or die "Couldn't open /tmp/ifcfg-$nic for writing: $!\n";

	print $newIfcfgFile "PEERDNS=\"no\"\n";
	print $newIfcfgFile "HWADDR=\"$macString\"\n";
	print $newIfcfgFile "NM_CONTROLLED=\"no\"\n";
	while ( my $line = <$ifcfgFile> ) {
		if (( $line =~ /PEERDNS/ ) || ( $line =~ /HWADDR/ ) || ( $line =~ /UUID/ ) || ( $line =~ /NM_CONTROLLED/ )) {
			next;
		}
		else {
			print $newIfcfgFile $line;
		}
	}
	print $newIfcfgFile "NM_CONTROLLED=\"no\"\n";
	close $ifcfgFile;
	close $newIfcfgFile;
	runAndLog( $fileout, "mv /tmp/ifcfg-$nic /etc/sysconfig/network-scripts/ifcfg-$nic" );

	runAndLog( $fileout, "echo \"ifconfig $nic txqueuelen 10000\" >>  /etc/rc.d/rc.local" );

}

# Tune netfilter
runAndLog( $fileout, "echo \"iptables -t nat -L\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "echo \"echo 1048576 > /proc/sys/net/nf_conntrack_max\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "echo \"echo 1048576 > /proc/sys/net/netfilter/nf_conntrack_max\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "echo \"echo 65536 > /sys/module/nf_conntrack/parameters/hashsize\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "echo \"echo 65536 > /sys/module/nf_conntrack_ipv4/parameters/hashsize\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "service network restart" );

runAndLog( $fileout, "cp configFiles/host/$os/*.repo /etc/yum.repos.d/." );
if ( $os eq "centos7" ) {
	runAndLog( $fileout, "systemctl stop avahi-daemon.socket" );
	runAndLog( $fileout, "systemctl stop avahi-daemon.service" );
	runAndLog( $fileout, "systemctl disable avahi-daemon.socket" );
	runAndLog( $fileout, "systemctl disable avahi-daemon.service" );
}

runAndLog( $fileout, "yum install -y wget" );
runAndLog( $fileout, "yum install -y curl" );
runAndLog( $fileout, "yum install -y lynx" );

print "Configuring ntp\n";
print $fileout "Configuring ntp\n";
runAndLog( $fileout, "yum install -y ntp" );
runAndLog( $fileout, "cp configFiles/host/$os/ntp.conf /etc/ntp.conf" );
if ( $serviceManager eq "init" ) {
	runAndLog( $fileout, "service ntpd restart" );
	runAndLog( $fileout, "chkconfig ntpd on" );
}
else {
	runAndLog( $fileout, "systemctl daemon-reload" );
	runAndLog( $fileout, "systemctl restart ntpd" );
	runAndLog( $fileout, "systemctl enable ntpd" );
}

print "Setting up various configuration files.  See autoSetup.log for details\n";
print $fileout "Setting up various configuration files.  See autoSetup.log for details\n";
runAndLog( $fileout, "cp configFiles/host/$os/sysctl.conf /etc/" );
runAndLog( $fileout, "cp configFiles/host/$os/rsyslog.conf /etc/" );
runAndLog( $fileout, "cp configFiles/host/$os/config /etc/selinux/" );
runAndLog( $fileout, "cp configFiles/host/$os/login /etc/pam.d/login" );
runAndLog( $fileout, "cp configFiles/host/$os/limits.conf /etc/security/limits.conf" );
runAndLog( $fileout, "cp configFiles/host/$os/bashrc /root/.bashrc" );
runAndLog( $fileout, "rm -rf /root/.ssh" );
runAndLog( $fileout, "cp -r configFiles/host/$os/ssh /root/.ssh" );
runAndLog( $fileout, "cp configFiles/host/$os/tls/certs/weathervane.crt /etc/pki/tls/certs/weathervane.crt" );
runAndLog( $fileout, "cp configFiles/host/$os/tls/private/weathervane.key /etc/pki/tls/private/weathervane.key" );
runAndLog( $fileout, "cp configFiles/host/$os/tls/private/weathervane.pem /etc/pki/tls/private/weathervane.pem" );
runAndLog( $fileout, "cp configFiles/host/$os/tls/openssl.cnf /etc/pki/tls/openssl.cnf" );
runAndLog( $fileout, "cp configFiles/host/$os/tls/weathervane.jks /etc/pki/tls/weathervane.jks" );
runAndLog( $fileout, "chmod -R 700 /root/.ssh" );
if ( $os eq "centos7" ) {
	runAndLog( $fileout, "cp configFiles/host/$os/redhat-release /etc/." );
}
runAndLog( $fileout, "yum install -y openssl-devel" );

print "Setting up the firewall (iptables)\n";
print $fileout "Setting up the firewall (iptables)\n";
if ( $os eq "centos6" ) {
	runAndLog( $fileout, "service iptables start" );
	runAndLog( $fileout, "chkconfig iptables on" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "service firewalld stop" );
	runAndLog( $fileout, "yum remove -y firewalld" );
	runAndLog( $fileout, "yum install -y iptables-services" );
	runAndLog( $fileout, "systemctl enable iptables" );
	runAndLog( $fileout, "systemctl start iptables" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 53 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p udp --dport 53 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p udp --dport 123 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 2376 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 7500 -j ACCEPT" );
	runAndLog( $fileout, "iptables-save > /etc/sysconfig/iptables" );
	runAndLog( $fileout, "systemctl stop iptables" );
}

print "Creating directories under /mnt\n";
print $fileout "Creating directories under /mnt\n";
runAndLog( $fileout, "mkdir /mnt/dbData" );
runAndLog( $fileout, "mkdir /mnt/dbLogs" );
runAndLog( $fileout, "mkdir /mnt/dbData/postgresql" );
runAndLog( $fileout, "mkdir /mnt/dbData/mysql" );
runAndLog( $fileout, "mkdir /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "mkdir /mnt/dbLogs/mysql" );
runAndLog( $fileout, "mkdir /mnt/mongoData" );
runAndLog( $fileout, "mkdir /mnt/imageStore" );
runAndLog( $fileout, "mkdir /mnt/zookeeper" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbData" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbLogs" );
runAndLog( $fileout, "chmod -R 777 /mnt/mongoData" );
runAndLog( $fileout, "chmod -R 777 /mnt/imageStore" );
runAndLog( $fileout, "chmod -R 777 /mnt/zookeeper" );
runAndLog( $fileout, "echo \"#LABEL=dbData  /mnt/dbData ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=dbLogs  /mnt/dbLogs ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=mongoData  /mnt/mongoData ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=imageStore  /mnt/imageStore ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=zookeeper  /mnt/zookeeper ext4 defaults 1 1\" >>  /etc/fstab" );

print "Fetching and installing Zookeeper\n";
print $fileout "Fetching and installing Zookeeper\n";
# Figure out the latest version of Zookeeper
my $zookeeperGet = `curl -s http://www.us.apache.org/dist/zookeeper/stable/`;
$zookeeperGet =~ />zookeeper-(\d+\.\d+\.\d+)\.tar\.gz</;
my $zookeeperVers = $1;
print $fileout "Detected that latest version of Zookeeper is $zookeeperVers\n";
runAndLog( $fileout,
"curl -s http://www.us.apache.org/dist/zookeeper/stable/zookeeper-$zookeeperVers.tar.gz -o /tmp/zookeeper-$zookeeperVers.tar.gz"
);
runAndLog( $fileout, "cd /tmp; tar zxf zookeeper-$zookeeperVers.tar.gz 2>&1; rm -r zookeeper-$zookeeperVers.tar.gz; mv zookeeper-$zookeeperVers /opt/zookeeper-$zookeeperVers" );
runAndLog( $fileout, "ln -s /opt/zookeeper-$zookeeperVers /opt/zookeeper" );


print "Fetching and installing Tomcat\n";
print $fileout "Fetching and installing Tomcat\n";
runAndLog( $fileout, "yum install -y gcc" );
runAndLog( $fileout, "yum install -y pcre-devel" );
# Figure out the latest version of Tomcat 8.5
my $tomcat8get = `curl -s http://www.us.apache.org/dist/tomcat/tomcat-8/`;
$tomcat8get =~ />v8\.5\.(\d+)\//;
my $tomcat8vers = $1;
print $fileout "Detected that latest version of Tomcat 8 is v8.5.$tomcat8vers\n";
runAndLog( $fileout,
"curl -s http://www.us.apache.org/dist/tomcat/tomcat-8/v8.5.$tomcat8vers/bin/apache-tomcat-8.5.$tomcat8vers.tar.gz -o /tmp/apache-tomcat-8.5.$tomcat8vers.tar.gz"
);
runAndLog( $fileout, "tar zxf /tmp/apache-tomcat-8.5.$tomcat8vers.tar.gz" );
runAndLog( $fileout, "rm -fr /opt/apache-tomcat-8.5.$tomcat8vers" );
runAndLog( $fileout, "rm -f /opt/apache-tomcat" );
runAndLog( $fileout, "mv apache-tomcat-8.5.$tomcat8vers /opt/" );
runAndLog( $fileout, "ln -s /opt/apache-tomcat-8.5.$tomcat8vers /opt/apache-tomcat" );
runAndLog( $fileout, "cp -r configFiles/host/$os/apache-tomcat-auction1 /opt/." );
runAndLog( $fileout, "mkdir /opt/apache-tomcat-auction1/webapps" );
runAndLog( $fileout, "cp /root/weathervane/dist/auctionWeb.war /opt/apache-tomcat-auction1/webapps/." );
runAndLog( $fileout, "cp /root/weathervane/dist/auction.war /opt/apache-tomcat-auction1/webapps/." );
runAndLog( $fileout, "mkdir /opt/apache-tomcat-auction1/bin" );
runAndLog( $fileout, "cp /opt/apache-tomcat/bin/tomcat-juli.jar /opt/apache-tomcat-auction1/bin/" );
runAndLog( $fileout, "mkdir /opt/apache-tomcat-auction1/work" );
runAndLog( $fileout, "mkdir /opt/apache-tomcat-auction1/temp" );
runAndLog( $fileout, "mkdir /opt/apache-tomcat-auction1/logs" );
runAndLog( $fileout, "mkdir /opt/apache-tomcat-auction1/lib" );
runAndLog( $fileout,
"curl -s http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.41/mysql-connector-java-5.1.41.jar -o /opt/apache-tomcat-auction1/lib/mysql-connector-java-5.1.41.jar"
);
runAndLog( $fileout,
"curl -s http://central.maven.org/maven2/org/postgresql/postgresql/9.4.1212.jre7/postgresql-9.4.1212.jre7.jar -o /opt/apache-tomcat-auction1/lib/postgresql-9.4.1212.jre7.jar"
);

print "Fetching and installing Httpd\n";
print $fileout "Fetching and installing Httpd\n";
runAndLog( $fileout, "yum install -y httpd" );
runAndLog( $fileout, "mkdir /var/cache/apache" );
runAndLog( $fileout, "chmod 777 /var/cache/apache" );
runAndLog( $fileout, "mkdir -p /var/www/vhosts/auction/html" );
runAndLog( $fileout, "cp /root/weathervane/dist/auctionWeb.tgz /var/www/vhosts/auction/html/" );
runAndLog( $fileout, "cd /var/www/vhosts/auction/html; tar zxf auctionWeb.tgz 2>&1; rm -r auctionWeb.tgz" );
runAndLog( $fileout, "mkdir /etc/systemd/system/httpd.service.d" );
runAndLog( $fileout, "cp configFiles/host/$os/limits-systemd.conf /etc/systemd/system/httpd.service.d/limits.conf" );

print "Installing keepalived\n";
print $fileout "Installing keepalived\n";
runAndLog( $fileout, "yum install -y keepalived" );

print "Installing haproxy\n";
print $fileout "Installing haproxy\n";
runAndLog( $fileout, "yum install -y haproxy" );
runAndLog( $fileout, "yum install -y mod_ssl" );
runAndLog( $fileout,
	"curl -s http://www.dest-unreach.org/socat/download/socat-1.7.3.0.tar.gz -o /tmp/socat-1.7.3.0.tar.gz" );
runAndLog( $fileout, "tar zxf /tmp/socat-1.7.3.0.tar.gz" );
runAndLog( $fileout, "cd /root/weathervane/socat-1.7.3.0;./configure 2>&1;make 2>&1;make install" );
runAndLog( $fileout, "rm -rf /root/weathervane/socat-1.7.3.0" );
runAndLog( $fileout, "mkdir /etc/systemd/system/haproxy.service.d" );
runAndLog( $fileout, "cp configFiles/host/$os/limits-systemd.conf /etc/systemd/system/haproxy.service.d/limits.conf" );

print "Installing sysstat\n";
print $fileout "Installing sysstat\n";
runAndLog( $fileout,
	"curl -s http://sebastien.godard.pagesperso-orange.fr/sysstat-11.1.4.tar.gz -o /tmp/sysstat-11.1.4.tar.gz" );
runAndLog( $fileout, "tar zxf /tmp/sysstat-11.1.4.tar.gz" );
runAndLog( $fileout, "cd /root/weathervane/sysstat-11.1.4;./configure 2>&1;make 2>&1;make install" );
runAndLog( $fileout, "rm -rf /root/weathervane/sysstat-11.1.4" );

print "Installing nginx\n";
print $fileout "Installing nginx\n";
if ( $os eq "centos6" ) {
	runAndLog( $fileout,
		"yum install -y http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout,
		"yum install -y http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm" );
}
runAndLog( $fileout, "yum install -y nginx" );
runAndLog( $fileout, "mkdir /var/cache/nginx" );
runAndLog( $fileout, "chown -R nginx:nginx /var/cache/nginx" );
runAndLog( $fileout, "rm -r /usr/share/nginx/html/*" );
runAndLog( $fileout, "cp /root/weathervane/dist/auctionWeb.tgz /usr/share/nginx/html/" );
runAndLog( $fileout, "cd /usr/share/nginx/html; tar zxf auctionWeb.tgz 2>&1; rm -r auctionWeb.tgz" );
runAndLog( $fileout, "chown -R nginx:nginx /usr/share/nginx" );
runAndLog( $fileout, "mkdir /etc/systemd/system/nginx.service.d" );
runAndLog( $fileout, "cp configFiles/host/$os/limits-systemd.conf /etc/systemd/system/nginx.service.d/limits.conf" );

print "Installing mysql\n";
print $fileout "Installing mysql\n";
if ( $os eq "centos6" ) {
	runAndLog( $fileout,
"curl -s http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm -o /tmp/mysql-community-release-el6-5.noarch.rpm"
	);
	runAndLog( $fileout, "yum install -y /tmp/mysql-community-release-el6-5.noarch.rpm" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout,
"curl -s http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm -o /tmp/mysql-community-release-el7-5.noarch.rpm"
	);
	runAndLog( $fileout, "yum install -y /tmp/mysql-community-release-el7-5.noarch.rpm" );
}
runAndLog( $fileout, "yum install -y mysql-community-server" );
if ( $os eq "centos6" ) {
	runAndLog( $fileout, "ln -s /etc/init.d/mysqld /etc/init.d/mysql" );
}
runAndLog( $fileout, "cp /root/weathervane/configFiles/mysql/my.cnf /etc/my.cnf" );
runAndLog( $fileout, "chown -R mysql:mysql /mnt/dbData/mysql" );
runAndLog( $fileout, "chown -R mysql:mysql /mnt/dbLogs/mysql" );
runAndLog( $fileout, "service mysqld start" );
runAndLog( $fileout, "mysql -u root -e \"CREATE USER 'auction' IDENTIFIED BY 'auction';\"" );
runAndLog( $fileout, "mysql -u root -e \"GRANT ALL ON *.* TO 'auction';\"" );
runAndLog( $fileout, "mysql -u root -e \"GRANT ALL ON *.* TO 'auction'\@'localhost';\"" );
runAndLog( $fileout, "mysql -u root -e \"drop user ''\@'localhost';\"" );
runAndLog( $fileout, "mysql -u root -e \"SET PASSWORD=PASSWORD('weathervane');\"" );
runAndLog( $fileout, "service mysqld stop" );
runAndLog( $fileout, "echo 'LimitNOFILE=infinity' >> /lib/systemd/system/mysqld.service");
runAndLog( $fileout, "echo 'LimitMEMLOCK=infinity' >> /lib/systemd/system/mysqld.service");
runAndLog( $fileout, "mkdir /etc/systemd/system/mysqld.service.d" );
runAndLog( $fileout, "cp configFiles/host/$os/limits-systemd.conf /etc/systemd/system/mysqld.service.d/limits.conf" );

if ( $os eq "centos6" ) {
	runAndLog( $fileout, "chkconfig mysql off" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "systemctl disable mysqld" );
}

print "Installing postgresql93\n";
print $fileout "Installing postgresql93\n";
runAndLog( $fileout, "echo \"exclude=postgresql*\" >> /etc/yum.repos.d/CentOS-Base.repo" );
if ( $os eq "centos6" ) {
	runAndLog( $fileout,
		"yum localinstall -y http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-3.noarch.rpm" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout,
		"yum localinstall -y http://yum.postgresql.org/9.3/redhat/rhel-7-x86_64/pgdg-centos93-9.3-3.noarch.rpm" );
}
runAndLog( $fileout, "yum install -y postgresql93" );
runAndLog( $fileout, "yum install -y postgresql93-server" );
if ( $os eq "centos6" ) {
	runAndLog( $fileout, "service postgresql-9.3 initdb" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "/usr/pgsql-9.3/bin/postgresql93-setup initdb" );
}
runAndLog( $fileout, "mv /var/lib/pgsql/9.3/data/* /mnt/dbData/postgresql" );
runAndLog( $fileout, "mv /mnt/dbData/postgresql/pg_xlog/* /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "cp configFiles/host/$os/pg_hba.conf /mnt/dbData/postgresql" );
runAndLog( $fileout, "rmdir /var/lib/pgsql/9.3/data; ln -s /mnt/dbData/postgresql /var/lib/pgsql/9.3/data" );
runAndLog( $fileout,
	"rmdir /mnt/dbData/postgresql/pg_xlog; ln -s /mnt/dbLogs/postgresql /mnt/dbData/postgresql/pg_xlog" );
runAndLog( $fileout, "chmod 700 /mnt/dbData/postgresql;chown -R postgres:postgres /mnt/dbData/postgresql" );
runAndLog( $fileout, "chown -R postgres:postgres /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "service postgresql-9.3 start" );
runAndLog( $fileout,
	"psql -U postgres -c \"create role auction with superuser createdb login password 'auction;'\"" );
runAndLog( $fileout, "psql -U postgres -c \"create database auction owner auction\"" );
runAndLog( $fileout, "service postgresql-9.3 stop" );
runAndLog( $fileout, "chmod 700 /mnt/dbData/postgresql" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "mkdir /etc/systemd/system/postgresql-9.3.service.d" );
runAndLog( $fileout, "cp configFiles/host/$os/limits-systemd.conf /etc/systemd/system/postgresql-9.3.service.d/limits.conf" );

print "Installing RabbitMQ\n";
print $fileout "Installing RabbitMQ\n";
runAndLog( $fileout, "wget http://www.rabbitmq.com/releases/erlang/erlang-17.4-1.el6.x86_64.rpm" );
runAndLog( $fileout, "yum install -y erlang-17.4-1.el6.x86_64.rpm" );
runAndLog( $fileout, "rm -f erlang-17.4-1.el6.x86_64.rpm" );
runAndLog( $fileout,
	"yum install -y http://www.rabbitmq.com/releases/rabbitmq-server/v3.5.3/rabbitmq-server-3.5.3-1.noarch.rpm" );

#runAndLog($fileout, "yum install -y /root/weathervane/configFiles/host/$os/rabbitmq-server-3.3.5-1.noarch.rpm");
runAndLog( $fileout, "chkconfig rabbitmq-server off" );
runAndLog( $fileout, "rabbitmq-plugins enable rabbitmq_management" );
runAndLog( $fileout, "cp configFiles/host/$os/rabbitmqadmin /usr/local/bin/" );
runAndLog( $fileout, "chmod +x /usr/local/bin/rabbitmqadmin" );

print "Installing mongodb-org\n";
runAndLog( $fileout, "yum install -y mongodb-org" );
runAndLog( $fileout, "chkconfig mongod off" );

print "Installing nfs\n";
runAndLog( $fileout, "yum install -y nfs-utils" );

print "Installing Perl Modules\n";
print $fileout "Installing Perl Modules\n";
runAndLog( $fileout, "yum install -y perl-App-cpanminus" );
runAndLog( $fileout, "cpanm YAML" );
runAndLog( $fileout, "cpanm Config::Simple" );
runAndLog( $fileout, "cpanm String::Util" );
runAndLog( $fileout, "cpanm Statistics::Descriptive" );
runAndLog( $fileout, "cpanm Moose" );
runAndLog( $fileout, "service network restart" );
runAndLog( $fileout, "cpanm MooseX::Storage" );
runAndLog( $fileout, "cpanm Tie::IxHash" );
runAndLog( $fileout, "cpanm MooseX::ClassAttribute" );
runAndLog( $fileout, "cpanm MooseX::Types" );
runAndLog( $fileout, "cpanm JSON" );
runAndLog( $fileout, "cpanm Switch" );
runAndLog( $fileout, "cpanm Log::Log4perl" );
runAndLog( $fileout, "cpanm Log::Dispatch::File" );
runAndLog( $fileout, "cpanm LWP" );
runAndLog( $fileout, "service network restart" );

print "Installing and configuring nscd\n";
print $fileout "Installing and configuring nscd\n";
runAndLog( $fileout, "yum install -y nscd" );

print "Installing and configuring Docker\n";
print $fileout "Installing and configuring Docker\n";
runAndLog( $fileout, "yum install -y docker-engine" );
if ( $os eq "centos6" ) {
	runAndLog( $fileout, "chkconfig docker on" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "cp -r configFiles/host/$os/docker.service.d /etc/systemd/system/." );
	runAndLog( $fileout, "systemctl daemon-reload" );
	runAndLog( $fileout, "systemctl enable docker" );
}

print "Installing and configuring the DNS Server\n";
print $fileout "Installing and configuring the DNS Server\n";
runAndLog( $fileout, "yum install -y bind" );
runAndLog( $fileout, "yum install -y bind-utils" );
runAndLog( $fileout, "cp configFiles/host/$os/weathervane.forward.zone /var/named/." );
runAndLog( $fileout, "cp configFiles/host/$os/named.conf /etc/named.conf" );
runAndLog( $fileout, "cp configFiles/host/$os/resolv.conf /etc/resolv.conf" );
runAndLog( $fileout, "chown root:named /etc/named.conf" );
runAndLog( $fileout, "service named start" );

close $fileout;

print "AutoSetup Complete.\n";
print "You still need to perform the following steps:\n";
print "    - Reboot this VM.\n";
print "    - Disable the sceensaver if you are running with a desktop manager.\n";
print "    - Before cloning this VM, edit the file /etc/resolv.conf so\n";
print "      that the IP address on the nameserver line is that of your primary driver.\n";
print "    - Clone this VM as appropriate for your deployment\n";
print "    - On the primary driver, edit the Weathervane configuration file as needed.\n";

1;
