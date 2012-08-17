#!/usr/bin/env perl 
#===============================================================================
#
#   FILE:  merge-s-and-t-layer.pl
#
#   USAGE:  ./merge-s-and-t-layer.pl [--stdout|-S  --skip|-K --compress|-c] <st-files>
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
use lib "$Bin/../libs/";
use SDataMerge;
use Getopt::Long;
GetOptions(
    "stdout|S"   => \our $use_stdout,
    "skip|K"     => \our $skip_existing_tmwe_files,
    "compress=i" => \our $compress,
    "outver=s"   => \our $output_version,
        # needs string -- '0.2' is not a number for GetOpt::Long
) or die "Usage: $0 [--stdout|-S --skip|-K --compress=(0|1)] "
		."[--outver 0.2] <st-files>\n";

if ( defined $compress and $compress != 0 and $compress != 1 ) {
    die
"The option --compress specifies whether the output should be gzipped. Its value must be 0 or 1.";
}

my $st_suffix = qr/\.st(?:\.gz|\.zip)?$/;

SFILE: foreach my $s_filename (@ARGV) {

    # Check which files to merge
    chomp $s_filename;
    if ( $s_filename !~ $st_suffix ) {
        warn "$s_filename is not named like an 'st' file.";
        next SFILE;
    }

    # check for pre-existing t-mwe files and whether we should skip them
    # or not. We look for ANY (gzipped or not) t-mwe files.
    my $t_mwe_file = $s_filename;
    $t_mwe_file =~ s/$st_suffix/\.t\.mwe/;
    my $t_mwe_file_gzipped = "$t_mwe_file" . ".gz";
    if ( $skip_existing_tmwe_files
        and ( -s $t_mwe_file or -s $t_mwe_file_gzipped ) )
    {
        warn
"$t_mwe_file already exists and you wanted to skip existing t-mwe files . ";
        next SFILE;
    }

    # Parse s-file and get a DOM
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $sdoc = $parser->parse_file($s_filename);

    # The merge itself (an external lib function)
    my $tdoc = SDataMerge::transform( $sdoc, $s_filename, $output_version );
    if ( $tdoc eq 'empty s-file' ) {
        print STDERR
          " Skipping the file $s_filename, because it contains no st-nodes . ";
        next SFILE;
    }

    # And output of the merged PML file to STDOUT or write to a file.
    # If the compression was not explicitly set (requested or forbidden),
    # then if the s-file was gzipped, compress the t-mwe file too.
    if ($use_stdout) {
        $tdoc->toFH( \*STDOUT );
    }
    else {
        my $tmwe_filename = $tdoc->URI;
        $tmwe_filename =~ s/t\.gz$/t\.mwe/;

        if (not defined $compress){ # the compression parameter was not given
            $compress = $s_filename =~ /\.gz|\.zip/ ? 1 : 0;
        }
        if ( $compress == 1 ) { 
            $tmwe_filename .= ".gz";
            $tdoc->setCompression('6');
        }
        else { $tdoc->setCompression('-1') }

        $tdoc->toFile( $tmwe_filename, 1 );
    }
}
