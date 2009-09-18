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
my $sroot = $stwig->root;
my @sdata = $sroot->children;
my @st    = $sdata[2]->children;
for my $snode (@st) {
    my @t_refs = $snode->children('t.rf');
    for my $trf (@t_refs) {
        print $trf->text, "\n";
    }
    print "\n";
}

my $tfile = substr( $sfile, 0, -2 );
$tfile = $tfile . 't';

my $ttwig = new XML::Twig;
$ttwig->parsefile("$tfile");
my $troot = $ttwig->root;
my @tdata = $troot->children;
my @ttree = $tdata[2]->children;
foreach my $snode (@st) {
    my @trf_node = $snode->children('t.rf');
    my @trf_text;
    for my $node (@trf_node) {
        my $t = $node->text;
        $t =~ s/t#t/t/;
        push @trf_text, $t;
    }
    my $s_first_id = $trf_text[0];

    foreach my $troot (@ttree) { 
        no warnings;
        my @lmembers = $troot->descendants('LM');
        my @tnode_ids = map { $_->att('id') } @lmembers;
        my $match = grep { $_ eq $s_first_id } @tnode_ids;
        if ($match){
            $snode->paste($troot);
            # TODO Modify s-node to the correct form first!
            # make a copy to paste.
        }
    }
}
