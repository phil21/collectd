#!/usr/bin/perl
# ZFS collectd 'get all' plugin

use warnings;
use Data::Dumper;
use Sys::Hostname;
use Pod::Usage;
use Getopt::Long;

my $VERSION = '1.0';
my $AUTHOR = 'Phil Doroff <phil@servercentral.com>';

$|=1;
$ENV{'PATH'} = "/usr/bin:/sbin";
my $zfs_cmd = 'zfs get -pH -t filesystem,volume all';
my @params  = qw (
                used referenced compressratio usedbysnapshots usedbydataset
                usedbychildren usedbyrefreservation logicalused 
                logicalreferenced quota available written
);

my ($interval,$hostname,$skip_syspool,$prefix,$help);
my $ts = time();

if ($ENV{'COLLECTD_INTERVAL'}) {
  $interval = $ENV{'COLLECTD_INTERVAL'};
}

Getopt::Long::GetOptions(
  'interval|i=i'  => \$interval,
  'hostname|h=s'  => \$hostname,
  'no-syspool'    => \$skip_syspool,
  'prefix'        => \$prefix,
  'help|h|?'      => \$help,
) or pod2usage(1);

if ($help) { pod2usage(-verbose => 2, -noperldoc => 1) }

$interval ||= 300;
$prefix ||= 'space';
$skip_syspool ||= 0;
$hostname ||= hostname();

while (1) {
  my @raw = `$zfs_cmd`;
  foreach (@raw) {
    chomp();
    # Dig out the parameters we want, and report them
    my @line = split(/\s+/,$_);
    if ($skip_syspool == 1 && $line[0] =~ /syspool/) { next; }
    foreach my $param (@params) {
      if ($param eq $line[1]) {
        # This parameter has a value we would like to report
        Output($line[0],$line[1],$line[2]);
      }
    }
  }
  sleep($interval);
}

sub Output {
  my $path = shift;
  my $param = shift;
  my $value = shift;
  # Clean up some values for ingest purposes
  # Path must be converted to dots (zpool.parent.parent/child)
  $path =~ s#/(?=.*/)#\.#g;
  # Remove any non-numeric values
  $value =~ s/[^0-9\.]//g;
  printf("PUTVAL %s.%s.%s/gauge-%s interval=%i %i:%s\n", $hostname, $prefix, $path, $param, $interval, $ts, $value);
}

__END__

=head1 NAME

zfs-getall-collectd.pl - Simple collectd EXEC plugin for 'zfs get all'

=head1 SYNOPSIS

zfs-getall-collectd.pl [options]

  Options:
    --interval    loop interval (default 5m)
    --hostname    override hostname (default Sys::Hostname)
    --prefix      collectd metric prefix (default space)
    --no-syspool   don't report stats for syspool (default off)

=head1 DESCRIPTION

B<zfs-getall-collectd.pl> interates over the output of "zfs get all" and 
reports appropriate metrics to collectd as a simple EXEC plugin.

Sane defaults are provided, but the variable @params may be tweaked to report
desired data.  Most useful values have to do with space utilization, while some
other values like compression ratio are also included by default.
