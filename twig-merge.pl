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

my $sfile = $ARGV[0] || die "No file passed: $!";
$sfile =~ /.st$/ || die "This is not an 'st' file.";

my $stwig = new XML::Twig;
$stwig->parsefile("$sfile");
my $sroot  = $stwig->root;
my @sdata = $root->children;
my @st    = $sdata[2]->children;
for my $snode (@st) {
    my @t_refs = $snode->children('t.rf');
    for my $trf (@t_refs) {
       print $trf->text, "\n"; 
    }
    print "\n";
}

my $tfile = substr($sfile, 0, -1);
my $ttwig = new XML::Twig;
$ttwig->parsefile("$tfile");
my $troot  = $ttwig->root;
my @tdata = $troot->children;
my @ttree = $tdata[2]->children;
foreach my $snode (@sdata){
    my @trf = $snode->children('t.rf');
    my $s_first_id = $trf[0] =~ s/t#t/t/;
    foreach my $troot (@ttrees) {
        if match($troot, $snode){
            $snode->paste($troot);
        }
    }
}

sub match {
    # projit strom (asi rekurzi) a overit, jestli obsahuje children/LM/@id =
    # $s_first_id
}
