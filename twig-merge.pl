#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  twig-merge.pl
#
#        USAGE:  ./twig-merge.pl
#
#  DESCRIPTION:  Integrate the s-layer annotation into the t-layer files.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
#      COMPANY:
#      VERSION:  1.0
#      CREATED:  2009/09/16 15:14:58
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use XML::Twig;

my $file = $ARGV[0] || die "No file passed: $!";
$file =~ /.st/ || die "This is not an 'st' file.";

my $twig = new XML::Twig;
$twig->parsefile("$file");
my $root  = $twig->root;
my @sdata = $root->children;
my @st    = $sdata[2]->children;
for my $snode (@st) {
    my @t_refs = $snode->children('t.rf');
    for my $trf (@t_refs) {
       print $trf->text, "\n"; 
    }
    print "\n";
}
