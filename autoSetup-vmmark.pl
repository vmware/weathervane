#!/usr/bin/perl
#
# Copyright by VMware
# Created by: Hal Rosenberg
# Modified by: James Zubb
# This script sets up weathervane for VMmark on Centos7
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
			die "The only distributions currently supported by this script is Centos 7/\n";
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

my $cmdout;
my $fileout;
open( $fileout, ">autoSetup.log" ) or die "Can't open file autoSetup.log for writing: $!\n";

my $os             = setOS();
my $serviceManager = setServiceManager($os);

print "Performing autoSetup for a $os host.\n";
print $fileout "Performing autoSetup for a $os host.\n";
runAndLog( $fileout, "setenforce 0" );

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
runAndLog( $fileout, "echo \"echo 131072 > /sys/module/nf_conntrack/parameters/hashsize\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "echo \"echo 131072 > /sys/module/nf_conntrack_ipv4/parameters/hashsize\" >>  /etc/rc.d/rc.local" );
runAndLog( $fileout, "service network restart" );

runAndLog( $fileout, "cp configFiles/host/$os/*.repo /etc/yum.repos.d/." );
if ( $os eq "centos7" ) {
	runAndLog( $fileout, "systemctl stop avahi-daemon.socket" );
	runAndLog( $fileout, "systemctl stop avahi-daemon.service" );
	runAndLog( $fileout, "systemctl disable avahi-daemon.socket" );
	runAndLog( $fileout, "systemctl disable avahi-daemon.service" );
}


#print "Configuring ntp\n";
#print $fileout "Configuring ntp\n";
#runAndLog( $fileout, "yum install -y ntp" );
#runAndLog( $fileout, "cp configFiles/host/$os/ntp.conf /etc/ntp.conf" );
#if ( $serviceManager eq "init" ) {
#	runAndLog( $fileout, "service ntpd restart" );
#	runAndLog( $fileout, "chkconfig ntpd on" );
#}
#else {
#	runAndLog( $fileout, "systemctl daemon-reload" );
#	runAndLog( $fileout, "systemctl restart ntpd" );
#	runAndLog( $fileout, "systemctl enable ntpd" );
#}

print "Setting up various configuration files.  See autoSetup.log for details\n";
print $fileout "Setting up various configuration files.  See autoSetup.log for details\n";
runAndLog( $fileout, "cp configFiles/host/$os/sysctl.conf /etc/" );
runAndLog( $fileout, "cp configFiles/host/$os/rsyslog.conf /etc/" );
runAndLog( $fileout, "cp configFiles/host/$os/config /etc/selinux/" );
runAndLog( $fileout, "cp configFiles/host/$os/login /etc/pam.d/login" );
runAndLog( $fileout, "cp configFiles/host/$os/bashrc /root/.bashrc" );
runAndLog( $fileout, "rm -rf /etc/pki/tls" );
runAndLog( $fileout, "cp -r configFiles/host/$os/tls /etc/pki/tls" );
if ( $os eq "centos7" ) {
	runAndLog( $fileout, "cp configFiles/host/$os/redhat-release /etc/." );
}

print "Setting up the firewall (iptables)\n";
print $fileout "Setting up the firewall (iptables)\n";
if ( $os eq "centos6" ) {
	runAndLog( $fileout, "service iptables start" );
	runAndLog( $fileout, "chkconfig iptables on" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "service firewalld stop" );
	runAndLog( $fileout, "yum --disablerepo=\* remove -y firewalld" );
	runAndLog( $fileout, "systemctl enable iptables" );
	runAndLog( $fileout, "systemctl start iptables" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 53 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p udp --dport 53 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 2376 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 6500 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 6550 -j ACCEPT" );
	runAndLog( $fileout, "iptables -I INPUT -p tcp --dport 7500 -j ACCEPT" );
	runAndLog( $fileout, "iptables-save > /etc/sysconfig/iptables" );
	runAndLog( $fileout, "systemctl stop iptables" );
}

print "Creating directories under /mnt\n";
print $fileout "Creating directories under /mnt\n";
runAndLog( $fileout, "mkdir /mnt/dbLogs" );
runAndLog( $fileout, "mkdir /mnt/dbData/postgresql" );
runAndLog( $fileout, "mkdir /mnt/dbData/mysql" );
runAndLog( $fileout, "mkdir /mnt/dbBackup" );
runAndLog( $fileout, "mkdir /mnt/dbBackup/postgresql" );
runAndLog( $fileout, "mkdir /mnt/dbBackup/mysql" );
runAndLog( $fileout, "mkdir /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "mkdir /mnt/dbLogs/mysql" );
runAndLog( $fileout, "mkdir /mnt/mongoBackup" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbData" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbLogs" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbBackup" );
runAndLog( $fileout, "chmod -R 777 /mnt/mongoData" );
runAndLog( $fileout, "chmod -R 777 /mnt/mongoBackup" );
runAndLog( $fileout, "chmod -R 777 /mnt/imageStore" );
runAndLog( $fileout, "echo \"#LABEL=dbData  /mnt/dbData ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=dbLogs  /mnt/dbLogs ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=dbBackup  /mnt/dbBackup ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=mongoData  /mnt/mongoData ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=mongoBackup  /mnt/mongoBackup ext4 defaults 1 1\" >>  /etc/fstab" );
runAndLog( $fileout, "echo \"#LABEL=imageStore  /mnt/imageStore ext4 defaults 1 1\" >>  /etc/fstab" );


runAndLog( $fileout, "cp /root/weathervane/configFiles/mysql/my.cnf /etc/my.cnf" );
runAndLog( $fileout, "chown -R mysql:mysql /mnt/dbData/mysql" );
runAndLog( $fileout, "chown -R mysql:mysql /mnt/dbLogs/mysql" );
runAndLog( $fileout, "service mysqld start" );
runAndLog( $fileout, "mysql -u root -e \"CREATE USER 'auction' IDENTIFIED BY 'auction';\"" );
runAndLog( $fileout, "mysql -u root -e \"GRANT ALL ON *.* TO 'auction';\"" );
runAndLog( $fileout, "mysql -u root -e \"GRANT ALL ON *.* TO 'auction'\@'localhost' identfied by 'auction';\"" );
runAndLog( $fileout, "mysql -u root -e \"SET PASSWORD=PASSWORD('weathervane');\"" );
runAndLog( $fileout, "mysql -u root -e \"drop user ''\@'localhost';\"" );
runAndLog( $fileout, "service mysqld stop" );
runAndLog( $fileout, "echo 'LimitNOFILE=infinity' >> /lib/systemd/system/mysqld.service");
runAndLog( $fileout, "echo 'LimitMEMLOCK=infinity' >> /lib/systemd/system/mysqld.service");

if ( $os eq "centos6" ) {
	runAndLog( $fileout, "chkconfig mysql off" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "systemctl disable mysqld" );
}

if ( $os eq "centos6" ) {
	runAndLog( $fileout, "service postgresql-9.5 initdb" );
}
elsif ( $os eq "centos7" ) {
	runAndLog( $fileout, "/usr/pgsql-9.5/bin/postgresql95-setup initdb" );
}
runAndLog( $fileout, "mv /var/lib/pgsql/9.5/data/* /mnt/dbData/postgresql" );
runAndLog( $fileout, "mv /mnt/dbData/postgresql/pg_xlog/* /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "cp configFiles/host/$os/pg_hba.conf /mnt/dbData/postgresql" );
runAndLog( $fileout, "rmdir /var/lib/pgsql/9.5/data; ln -s /mnt/dbData/postgresql /var/lib/pgsql/9.5/data" );
runAndLog( $fileout,
	"rmdir /mnt/dbData/postgresql/pg_xlog; ln -s /mnt/dbLogs/postgresql /mnt/dbData/postgresql/pg_xlog" );
runAndLog( $fileout, "chmod 700 /mnt/dbData/postgresql;chown -R postgres:postgres /mnt/dbData/postgresql" );
runAndLog( $fileout, "chown -R postgres:postgres /mnt/dbLogs/postgresql" );
runAndLog( $fileout, "service postgresql-9.5 start" );
runAndLog( $fileout,
	"psql -U postgres -c \"create role auction with superuser createdb login password 'auction;'\"" );
runAndLog( $fileout, "psql -U postgres -c \"create database auction owner auction\"" );
runAndLog( $fileout, "service postgresql-9.5 stop" );
runAndLog( $fileout, "chmod 700 /mnt/dbData/postgresql" );
runAndLog( $fileout, "chmod -R 777 /mnt/dbLogs/postgresql" );


#print "Installing and configuring the DNS Server\n";
#runAndLog( $fileout, "cp configFiles/host/$os/resolv.conf /etc/resolv.conf" );
#runAndLog( $fileout, "service named start" );

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
