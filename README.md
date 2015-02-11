Sys-snap logs resource usage to help troubleshoot load issues. Logs are stored in '/root/system-snapshot'. Log size varies depending on the number of users and processes running. Small to medium servers will use about 50-250MB of storage. 

You can download the script to the '/root' directory by running this command:
```
wget -O /root/sys-snap.pl https://raw.githubusercontent.com/jaivkjdrpaldk/tmp-sys-snap/master/sys-snap.pl
```

If you do not have the 'wget' program you can install it by running:
```
yum install -y wget
```

To install the program run. It will ask for confirmation to install:
```
cd /root/ && chmod 744 sys-snap.pl && perl sys-snap.pl --install
```

Sys-snap will run in the background. Logs will be written to /root/sys-snapshot/ every minute. Every hour a new folder with the current hour will be created. After 24 hours the folder should look like this:
***
root@server[/root/system-snapshot]# ls
./  ../  0/  1/  10/  11/  12/  13/  14/  15/  16/  17/  18/  19/  2/  20/  21/  22/  23/  3/  4/  5/  6/  7/  8/  9/  current@
***

Each hour will have logs that were created for every minute of the hour:
***
root@server[/root/system-snapshot/0]# ls
./     10.log  13.log  16.log  19.log  21.log  24.log  27.log  2.log   32.log  35.log  38.log  40.log  43.log  46.log  49.log  51.log  54.log  57.log  5.log  8.log
../    11.log  14.log  17.log  1.log   22.log  25.log  28.log  30.log  33.log  36.log  39.log  41.log  44.log  47.log  4.log   52.log  55.log  58.log  6.log  9.log
0.log  12.log  15.log  18.log  20.log  23.log  26.log  29.log  31.log  34.log  37.log  3.log   42.log  45.log  48.log  50.log  53.log  56.log  59.log  7.log
***

After 24 hours the logs will start to overwrite the previous logs. Each minute will overwrite the oldest log file. The logs are based on 24 hour time. 0 is 12AM.

Sys-snap can print the CPU and Memory of users for a time range. To print the basic resource usage for a time range, use the '--print' parameter along with a start and end time. This command will print the basic usage from 1AM to 2AM:

This command will need to be run in the same directory 'sys-snap.pl' was downloaded to:
```
perl sys-snap.pl --print 1:00 2:00
```

Example output from the above command.
***
user: dovecot        
        cpu-score: 0.20         
        memory-score: 2.40        

user: dovenull       
        cpu-score: 0.00         
        memory-score: 24.40       

user: mailnull       
        cpu-score: 0.00         
        memory-score: 5.30        

user: munin          
        cpu-score: 65.10        
        memory-score: 6.00        

user: mysql          
        cpu-score: 432.60         
        memory-score: 1362.30     

user: named          
        cpu-score: 0.00         
        memory-score: 0.00        

user: nobody         
        cpu-score: 35.00         
        memory-score: 135.70      

user: root           
        cpu-score: 83.70        
        memory-score: 607.60 
***

This is an alphabetical list of users, with the CPU and Memory usage they had during the time range. A larger score indicates larger resource usage. Many Apache processes will run as the 'nobody' user.

To print the processes each user was running during that time, add the 'v' flag to the end of the command.
```
perl sys-snap.pl --print 1:00 2:00 v
```

Example output from the above command:
***
user: dovecot         
...memory-score: 84.30       memory-score:
......M: 84.30 proc: \_ dovecot/auth
......M: 0.00 proc: \_ dovecot/anvil
...cpu-score: 6.90      
......C: 6.90 proc: \_ dovecot/auth
......C: 0.00 proc: \_ dovecot/anvil	
user: munin           
...memory-score: 6.70        memory-score:
......M: 3.30 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-update
......M: 1.80 proc: \_ /usr/local/cpanel/3rdparty/share/munin/munin-update [Munin::Master::UpdateWorker<server.com;host.server.com>]
......M: 0.70 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-limits
......M: 0.60 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-graph --cron
......M: 0.30 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-html
......M: 0.00 proc: \_ /bin/sh /usr/local/cpanel/3rdparty/perl/514/bin/munin-cron
...cpu-score: 106.40    
......C: 59.90 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-update
......C: 21.00 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-limits
......C: 17.00 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-graph --cron
......C: 8.00 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-html
......C: 0.50 proc: \_ /usr/local/cpanel/3rdparty/share/munin/munin-update [Munin::Master::UpdateWorker<server.com;host.server.com>]
......C: 0.00 proc: \_ /bin/sh /usr/local/cpanel/3rdparty/perl/514/bin/munin-cron
***

This command will check if sys-snap is running.
```
perl sys-snap.pl --check
```

To stop sys-snap run this from the directory sys-snap.pl was downloaded to. It will ask for confirmatino to kill the process.
```
perl sys-snap.pl --kill
```

You can use the 'sar' command to determin high load intervals which need to be looked at in closer detail.
Output from the 'sar' command: 
***
Linux 2.6 (host.server.com)    01/02/2101      _x86_64_        (24 CPU)

12:00:02 AM     CPU     %user     %nice   %system   %iowait    %steal     %idle
12:10:02 AM     all      0.38      0.29      0.17      0.01      0.04     99.11
12:20:02 AM     all      0.91      0.30      0.24      0.02      0.05     98.49
12:30:02 AM     all      4.03      0.32      0.71      0.15      0.10     94.69
12:40:02 AM     all     35.99      0.31     20.33      0.73      0.26     50.34
12:50:01 AM     all     75.40      0.27     30.17      1.01      0.04     00.12
01:00:02 AM     all     55.38      0.33     25.16      0.90      0.02     20.10
01:10:01 AM     all      0.41      0.30      0.17      0.01      0.05     99.06
01:20:01 AM     all      0.39      1.29      0.29      0.13      0.05     97.84 
***

In this case, to show detailed usage about a key interval above:
```
perl sys-snap.pl --print 00:30 1:10 v
```

More information about 'sar' and sysstat here:
[link text itself]: http://man7.org/linux/man-pages/man5/sysstat.5.html
