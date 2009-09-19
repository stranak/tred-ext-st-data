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
#         BUGS:  Will create duplicate <st> nodes, if there are some on input. 
#        NOTES:  ---
#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
#      COMPANY:
#      VERSION:  1.0
#      CREATED:  2009/09/16 15:14:58
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use open qw/:utf8 :std/;
use XML::Twig;

# Parse s-file and get s-nodes
my $sfile = $ARGV[0] || die "No file passed: $!";
$sfile =~ /.st$/ || die "This is not an 'st' file.";
my $stwig = new XML::Twig;
$stwig->parsefile("$sfile");
my $sroot = $stwig->root;
my @sdata = $sroot->children;
my @st    = $sdata[2]->children;

# Parse t-file and get t-trees
my $tfile = substr( $sfile, 0, -2 );
$tfile = $tfile . 't';
my $ttwig = new XML::Twig(pretty_print => 'nice');
$ttwig->parsefile("$tfile");
my $troot = $ttwig->root;
my @tdata = $troot->children;
my @ttree = $tdata[2]->children;

# Modify the s-nodes to the correct form and merge them into t-trees
SNODE: foreach my $snode (@st) {
    my $lex_id = $snode->first_child('lexicon-id');
    $lex_id->cut;
    $snode->insert('tnodes');
    my $tnodes_list = $snode->first_child('tnodes');
    $lex_id->paste( 'first_child', $snode );
    my @tnodes = $tnodes_list->children;
    map {
        $_->set_tag('LM');
        my $t = $_->text;
        $t =~ s/t#t/t/;
        $_->set_text($t);
    } @tnodes;
    my $s_first_tnode = $tnodes[0]->text;

    #########################################################
    # TODO change this: get rid of 't#' in place (or a copy),
    #    my @trf_node = $snode->children('t.rf');
    #    my @trf_text;
    #    foreach my $node (@trf_node) {
    #        my $t = $node->text;
    #        $t =~ s/t#t/t/;
    #        push @trf_text, $t;
    #    }
    #    my $s_first_id = $trf_text[0];
    ####### end of a block to modify #######################

  TNODE: foreach my $troot (@ttree) {
        no warnings;
        my @lmembers  = $troot->descendants('LM');
        my @tnode_ids = map { $_->att('id') } @lmembers;
        my $match     = grep { $_ eq $s_first_tnode } @tnode_ids;
        my ($mwes_exist, $mwes);
        if ( $troot->first_child('mwes') ) {
            $mwes_exist = 1;
            $mwes       = $troot->first_child('mwes');
        }
        else {
            $mwes = new XML::Twig::Elt('mwes');
        }
        if ($match) {
            $mwes->paste($troot) if not $mwes_exist;
            $snode->move( 'last_child', $mwes );

            #            $troot->print('indented');
            #            die;
        }
    }
}
$ttwig->print();
