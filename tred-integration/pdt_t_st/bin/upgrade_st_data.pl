#!/usr/bin/perl 
# author: Pavel Stranak (stranak@ufal.mff.cuni.cz),
use strict;
use warnings;
use XML::LibXML;

use FindBin qw($Bin);
use lib "$FindBin::Bin";
use File::Copy;
use SDataMerge;
use Getopt::Long;
GetOptions( "stdout|S" => \our $use_stdout, "inplace|i" => \our $in_place )
  or die "Usage: $0 [--stdout|-S] [--inplace|-i] <st-files>\n";

my $st_suffix = qr/\.st\.g?zi?p?$/;

foreach my $filename (@ARGV) {

    # Parse s-file and get a DOM
    if ( $filename !~ $st_suffix ) {
        warn "$filename does not look like an 'st' file.";
        next;
    }
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $sdoc = $parser->parse_file($filename);
    $sdoc = SDataMerge::upgrade_st($sdoc);
    if ($use_stdout) {
        $sdoc->toFH( \*STDOUT );
    }
    elsif ($in_place) {
    }
    else {
        copy($filename, "$filename.old.gz") if not $in_place;
        $sdoc->setCompression('6');
        $sdoc->toFile( $filename, 1 );
    }
}
