#!/usr/bin/perl -w

use strict;
use Switch;
#use POSIX qw(setsid);

my $usage = <<"ENDTXT"; 
USAGE: ./sys-snap.pl [options]
Installation:
	--install
PRINTING:
	--print <start-time end-time> <flag>: where time HH:MM, prints basic usage by default, v for verbose output 
ENDTXT

my $cmd_input;
if(!defined $ARGV[0]) { print $usage; exit;}
if ($ARGV[0] =~ m/[A-Za-z0-9\-]*/) {
	$cmd_input = $ARGV[0];
}

switch ($cmd_input) {
	case "--install" { &run_install; }
	case "--print" { &snap_print_range($ARGV[1], $ARGV[2], $ARGV[3]); } 
	else { print $usage; exit }
}

exit;

# pro-scope 255 ACM caffeine
{
sub snap_print_range {

use Time::Piece;
use Time::Seconds;

my $root_dir = '/root';
my $snapshot_dir = '/system-snapshot';

# not using this yet, but if we parse a range of data that crosses this file the resulting data is noncontigous
# and might be misleading. printing a warning might be apropriate in this scenario or having some other flag
# to indicate this has happened
my $newest_file = qx(ls -la ${root_dir}/system-snapshot/current);
my $time1 = shift;
my $time2 = shift;
my $detail_level = shift;

if (!defined $time1 || !defined $time2) { print "Need 2 parameters, \"./snap-print start-time end-time\"\n"; exit;}

my ($time1_hour, $time1_minute, $time2_hour, $time2_minute);

# make sub
if ( ($time1_hour, $time1_minute) = $time1 =~ m{^(\d{1,2}):(\d{2})$}){
	if($time1_hour >= 0 && $time1_hour <= 23 && $time1_minute >= 0 && $time1_minute <= 59) {
		#print "$time1_hour $time1_minute\n";
	} else { print "Fail: Fictitious time.\n"; exit; }
	
} else { print "Fail: Could not parse start time\n"; exit; }

if ( ($time2_hour, $time2_minute) = $time2 =~ m{(\d{1,2}):(\d{2})}){
	if($time2_hour >= 0 && $time2_hour <= 23 && $time2_minute >= 0 && $time2_minute <= 59) {
		#print "$time2_hour $time2_minute\n";
	} else { print "Fail: Fictitious time.\n"; exit; }

} else { print "Fail: Could not parse end time\n"; exit; }


# get the files we want to read
my @snap_log_files = &get_range($root_dir, $snapshot_dir, $time1_hour, $time1_minute, $time2_hour, $time2_minute);

# read 'em
my ($tmp1, $tmp2) = &read_logs(\@snap_log_files);

## waste resources dereffing stuff
## going to turn all this stuff into classes later
# users cumulative CPU and Mem score
my %basic_usage = %$tmp1;

#raw data from logs
my %process_list_data = %$tmp2;

# weighted process & memory
my %users_wcpu_process;
my %users_wmemory_process;

# instead of having an extended subrutine, just going to fall into the rest of the file
if ( !(defined $detail_level) || $detail_level eq 'b') { &run_basic(\%basic_usage); exit}

# adding up memory and CPU usage per user's process
foreach my $user (sort keys %process_list_data) {
	
	foreach my $process (sort keys %{ $process_list_data{$user} }) {

		$users_wcpu_process{$user}{$process} += $process_list_data{$user}{$process}{'cpu'};
		$users_wmemory_process{$user}{$process} += $process_list_data{$user}{$process}{'memory'};  
	}  
}

# create hash of sorted arrays per user
# print baisc usage appended with sorted arrays
my %users_sorted_mem;
my %users_sorted_cpu;
foreach my $user (sort keys %users_wmemory_process) {

	my @sorted_cpu = sort { $users_wcpu_process{$user}{$b} <=>
			     $users_wcpu_process{$user}{$a} } keys %{$users_wcpu_process{$user}};

	my @sorted_mem = sort { $users_wmemory_process{$user}{$b} <=>
			     $users_wmemory_process{$user}{$a} } keys %{$users_wmemory_process{$user}};
	
	# supposedly hash keys can't be tainted so printf should? be ok here, but maybe I'm misunderstanding this. Using print on unsanitized process string just in case
	# # https://www.securecoding.cert.org/confluence/display/perl/IDS01-PL.+Use+taint+mode+while+being+aware+of+its+limitations
	
	printf "user: %-15s \n\tmemory-score: %-11.2f memory-score:\n", $user, $basic_usage{$user}{'memory'};

	for (@sorted_mem) { 
		printf "\t\tM: %4.2f proc: ", $users_wmemory_process{$user}{$_};
		print "$_\n"; 
	}  

	printf "\n\tcpu-score: %-10.2f\n", $basic_usage{$user}{'cpu'};

	for (@sorted_cpu) { 
		printf "\t\tC: %4.2f proc: ", $users_wcpu_process{$user}{$_};
		print "$_\n"; 
	}
	print "\n";
}

##################### 
# Operator, I need an
exit;
#####################


# train BASIC every day
sub run_basic {
	my $tmp = shift;
	my %basic_usage = %$tmp;
	#my %basic_usage = shift;
	foreach my $user (sort keys %basic_usage){
		printf "user: %-15s\n\tcpu-score: %-12.2f \n\tmemory-score: %-12.2f\n\n", $user, $basic_usage{$user}{'cpu'}, $basic_usage{$user}{'memory'};
	}

	return;
}

## should be rewritten to take parameters of log subsections to be read
# returns hash of hashes
sub read_logs {

	my $tmp = shift;
	my @snap_log_files = @$tmp;

	my %process_list_data;
	my %basic_usage;

	foreach my $file_name (@snap_log_files) {

		my @lines;
		
		open (my $FILE, "<", $file_name) or next; #die "Couldn't open file: $!";
		my $string = join("", <$FILE>);
		close ($FILE);		
		
		# reading line by line to split the sections might be faster
		my $matchme = "USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND\n";
		if($string =~ /^$matchme(.*)\nNetwork Connections\:$/sm){
        		my $baseString=$1;
			@lines = split(/\n/, $baseString);
		}
		
		foreach my $l (@lines) {
			my ($user, $cpu, $memory, $command);
			($user, $cpu, $memory, $command) = $l =~  m{^(\w+)\s+\d+\s+(\d{1,2}\.\d)\s+(\d{1,2}\.\d).*\d{1,2}:\d{2}\s+(.*)$};
			
			if (defined $user && defined $cpu && defined $memory && defined $command) {
				
				# 
				if ($user !~ m/[a-zA-Z0-9_\.\-]+/) { next; }
				if ($cpu !~ m/[0-9\.]+/ && $memory !~ m/[0-9\.]+/) { next; }
				$basic_usage{$user}{'memory'} += $memory;
				$basic_usage{$user}{'cpu'} += $cpu;
				# agrigate hash? of commands - roll object
				
				# if the process is the same, accumulate it, if not create it
				# assuming if we have a memory value for a command, we should have a cpu value - nothing can ever go wrong here :smiley face:
				if (defined $process_list_data{$user}{$command}{'memory'}) {
					$process_list_data{$user}{$command}{'memory'} += $memory;
					$process_list_data{$user}{$command}{'cpu'} += $cpu;
				} 
				else {
					$process_list_data{$user}{$command}{'cpu'} = $cpu;
					$process_list_data{$user}{$command}{'memory'} = $memory;
				}
			}
		}
	}
	return (\%basic_usage, \%process_list_data);
}

# returns ordered array of stings that represent file location
# could create $accuracy variable to run modulo integers for faster processing at expense of accuracy 
sub get_range {

	my $root_dir = shift;
	my $snapshot_dir = shift;
	my $time1_hour = shift;
	my $time1_minute = shift;
	my $time2_hour = shift;
	my $time2_minute = shift;
	my $time1 = "$time1_hour:$time1_minute";
	my $time2 = "$time2_hour:$time2_minute";

	my @snap_log_files;	
	my ($file_hour, $file_minute);
	# Even if we want to ignore the date, Time::Piece will create one. This is probably easier than rolling a custom time cycle for over night periods such as 23:57 0:45,
	# and should make modification easier if longer date ranges are added too.
	# Mind the date format 'DAY MONTH YEAR(XXXX)'
 	my $start_time = Time::Piece->strptime("2-2-1993 $time1", "%d-%m-%Y %H:%M");
	my $end_time;
	
	if($time1_hour < $time2_hour || ($time1_hour == $time2_hour && $time1_minute < $time2_minute)) {
		$end_time = Time::Piece->strptime("2-2-1993 $time2", "%d-%m-%Y %H:%M");
	} else {
		$end_time = Time::Piece->strptime("3-2-1993 $time2", "%d-%m-%Y %H:%M");
	}
	
	while ($start_time <= $end_time ) {

		#print $start_time->strftime('%H:%M') . "\n";
		($file_hour,$file_minute) = split( /:/, $start_time->strftime('%H:%M') );

		#sys-snap not currently appending 0's to the front of files
		$file_minute =~ s/^0(\d)$/$1/;
		$file_hour =~ s/^0(\d)$/$1/;
		#print "$root_dir$snapshot_dir/$file_hour/$file_minute.log\n";
		push @snap_log_files, "$root_dir$snapshot_dir/$file_hour/$file_minute.log";
		$start_time += 60;	
	}

	return @snap_log_files;
}

# log files have load average as first line
# would be nifty to automatically find high ranges and then print stuff
}
}

# despite this whole page I am still just scoped in a cage - Cilly Borgan
{
sub run_install {

#my $is_running = `ps aux | grep '^\.\/sys-snap.pl --install\\|^perl'`;
my $is_running = `ps aux | grep '^root.*[s]ys-snap.pl --install'`;

# when you run the script with --install it will match itself, so if there are 2 matches then there is itself
# and probably an already running process 
if($is_running =~ m/.*\n.*\n/m) { print "Sys-snap is already running\n"; exit; }

use File::Path qw(rmtree);
use POSIX qw(setsid);

###############
# Set Options #
###############

# Set the time between snapshots in seconds
my $sleep_time = 60;

# The base directory under which to build the directory where snapshots are stored.
my $root_dir = '/root';

# Sometimes you won't have mysql and/or you won't have the root password to put in a .my.cnf file
# if that's the case, set this to 0
my $mysql = 1;

# If the server has lighttpd or some other webserver, set this to 0
# cPanel is autodetected later, so this setting is not used if running cPanel.
my $apache = 1;

# If you want extended data, set this to 1
my $max_data = 0;

############################################################################
# If you don't know what your doing, don't change anything below this line #
############################################################################

##########
# Set Up #
##########

# Get the date, hour, and min for various tasks
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
$year += 1900;    # Format year correctly
$mon++;           # Format month correctly
$mon  = 0 . $mon  if $mon < 10;
$mday = 0 . $mday if $mday < 10;
my $date = $year . $mon . $mday;

# Ensure target directory exists and is writable
if ( !-d $root_dir ) {
    die "$root_dir is not a directory\n";
}
elsif ( !-w $root_dir ) {
   die "$root_dir is not writable\n"; 
}

if ( -d "$root_dir/system-snapshot" ) {
    system 'tar', 'czf', "${root_dir}/system-snapshot.${date}.${hour}${min}.tar.gz", "${root_dir}/system-snapshot";
    rmtree( "$root_dir/system-snapshot" );
}

if ( !-d "$root_dir/system-snapshot" ) {
    mkdir "$root_dir/system-snapshot";
}

# try to split process into background
chdir '/' or die "Can't chdir to /: $!";
open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";
open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";

##########
# Main() #
##########

while (1) {

    # Ensure we have a current date/time
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $year += 1900;    # Format year correctly
    $mon++;           # Format month correctly
    $mon  = 0 . $mon  if $mon < 10;
    $mday = 0 . $mday if $mday < 10;
    $date = $year . $mon . $mday;

    # go to the next log file
    mkdir "$root_dir/system-snapshot/$hour";
    my $current_interval = "$hour/$min";

    my $logfile = "$root_dir/system-snapshot/$current_interval.log";
    open( my $LOG, '>', $logfile )
        or die "Could not open log file $logfile, $!\n";

    # start actually logging #
    my $load = qx(cat /proc/loadavg);
    #print $LOG "Load Average:\n\n";  # without this line, you can get historical loads with head -n1 *
    print $LOG "$date $hour $min Load Average: $load\n";

    print $LOG "Memory Usage:\n\n";
    print $LOG qx(cat /proc/meminfo), "\n";

    print $LOG "Virtual Memory Stats:\n\n";
    print $LOG qx(vmstat 1 10), "\n";

    print $LOG "Process List:\n\n";
    print $LOG qx(ps auwwxf), "\n";

    print $LOG "Network Connections:\n\n";
    print $LOG qx(netstat -anp), "\n";

    # optional logging
    if ($mysql) {
        print $LOG "MYSQL Processes:\n\n";
        print $LOG qx(mysqladmin proc), "\n";
    }

    print $LOG "Apache Processes:\n\n";
    if ( -f '/usr/local/cpanel/cpanel' ) {
        print $LOG qx(lynx --dump localhost/whm-server-status), "\n";
    }
    elsif ($apache) {
        print $LOG qx#lynx -width=1024 -dump http://localhost/server-status | egrep '(Client.+Request|GET|POST|HEAD)'#, "\n";
    }

    if ($max_data) {
        print $LOG "Process List for user Nobody:\n\n";
        my @process_list = qx(ps aux | grep [n]obody | awk '{print \$2}');
        foreach my $process (@process_list) {
            print $LOG qx(ls -al /proc/$process | grep cwd | grep home);
        }
        print $LOG "List of Open Files:\n\n";
        print $LOG qx(lsof), "\n";
    }

    close $LOG;

    # rotate the "current" pointer
    rmtree( "$root_dir/system-snapshot/current" );
    symlink "${current_interval}.log", "$root_dir/system-snapshot/current";

    sleep($sleep_time);
}
}
}
