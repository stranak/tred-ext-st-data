#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  merge-s-and-t-layer.pl
#
#        USAGE:  ./merge-s-and-t-layer.pl [--stdout|-S  --skip|-K] <st-files>
#
#  DESCRIPTION:  Integrate the s-layer annotation into the t-layer files.
#
#      OPTIONS:  ---
# REQUIREMENTS:  Corresponding t-files in the same directory.
#         BUGS:  Will create duplicate <st> nodes, if there are already some
#                in the input t-file.
#        NOTES:  ---
#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
#===============================================================================

use strict;
use warnings;
use XML::LibXML;

use FindBin qw($Bin);
use lib "$FindBin::Bin";
use SDataMerge;
use Getopt::Long;
GetOptions("stdout|S" => \ our $use_stdout,
           "skip|K" => \ our $skip_existing_st_files)
  or die "Usage: $0 [--stdout|-S] [--skip|-K] <st-files>\n";

my $st_suffix = qr/\.st\.g?zi?p?$/;

foreach my $s_filename (@ARGV) {

    # Parse s-file and get a DOM
    chomp $s_filename;
    if ($s_filename !~ $st_suffix ) {
        warn "$s_filename is not named like an 'st' file.";
        next;
    }
    my $t_mwe_file = $s_filename;
    $t_mwe_file =~ s/$st_suffix/\.t\.mwe\.gz/;
    if ($skip_existing_st_files and -s $t_mwe_file){
        warn "$t_mwe_file already exists.";
        next;
    }
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $sdoc   = $parser->parse_file($s_filename);
    my $tdoc = SDataMerge::transform($sdoc);
    if ($use_stdout) {
      $tdoc->toFH(\*STDOUT);
    } else {
      my $tmwe_filename = $tdoc->URI;
      $tmwe_filename =~ s/t\.gz$/t\.mwe\.gz/;
      $tdoc->setCompression('6');
      $tdoc->toFile( $tmwe_filename, 1 );
    }
}
