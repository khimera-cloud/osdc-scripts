#!/usr/bin/expect -f

set username [lindex $argv 0]
set hostname [lindex $argv 1]
set userpass [lindex $argv 2]
set rootpass [lindex $argv 3]

set sshkey "keys/$hostname.key"
set sshkeypub "$sshkey.pub"

set sshopts "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if { $username == "" || $hostname == "" } {
	send_user "Usage: $argv0 \<username\> \<hostname\> (userpass) (rootpass)\n"
	exit 1
}

log_user 0

#generate key
if { [file exists $sshkey] == 0} {
	file mkdir keys
	exec ssh-keygen -N "" -f $sshkey -C "$username@$hostname"
	send_user "\[] $sshkey generated\r\n"
} else {
#Check if root ssh key is already installed
	eval spawn ssh $sshopts -i $sshkey root@$hostname
	expect "*# " {
		send_user "\[] ssh key already installed on $hostname\r\n"
		send "exit\r\n"
		exit
	} "*?assword:" {
		close
	} "refused" {
		close
		send_user "\[] sshd not running on $hostname\r\n"
		exit 1
	}
}

set fp [open "$sshkeypub" r]
set sshkeypubline [read $fp]
close $fp

#login as user - check if argv3 password can be bypassed by an already installed key
eval spawn ssh $sshopts -i $sshkey $username@$hostname
expect "*?assword:" {
		send "$userpass\r"
	} "*$ " {
		send "\r"
	} denied {
		send_user "\[] $username password and/or key not accepted on host $hostname\r\n"
		exit 1
	}

#try to use sudo
expect "*$ " {
		send "sudo su -\r"
	} "?assword:" {
		close
		send_user "\[] bad password for $username on host $hostname\r\n"
		exit 1
	} close {
		send_user "\[] $username password not accepted on host $hostname\r\n"
		exit 1
	}

#if sudo didn't work try su with argv4 as password
expect "*# " {
	send "\r"
	} "*$ " {
	send "su -\r"
	expect "?assword:"
	send "$rootpass\r"
	expect "*# " {
		send "\r"
		} "*$ " {
			send "exit\r\n"
			send_user "\[] root password not accepted on host $hostname\r\n"
			exit 1
		}
	}

#add key - and only this key, effectively removing AWS template root restrictions - backup first
expect "*# "
send "cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.smbak\r"
expect "*# "
send "mkdir -p /root/.ssh; echo -n \"$sshkeypubline\" \> /root/.ssh/authorized_keys\r"

#permit root to ssh with key
expect "*# "
send "sed -i \'s/PermitRootLogin no/PermitRootLogin prohibit-password/g\' /etc/ssh/sshd_config\r"

expect "*# "
send "/etc/init.d/ssh restart\r"

expect "*# "
send "exit\r"

expect "*$ "
send "exit\r\n"

send_user "\[] ssh key installed to $hostname\n"
