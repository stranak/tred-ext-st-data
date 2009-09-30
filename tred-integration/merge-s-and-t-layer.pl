#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  merge-s-and-t-layer.pl
#
#        USAGE:  ./merge-s-and-t-layer.pl <st-file>
#
#  DESCRIPTION:  Integrate the s-layer annotation into the t-layer files.
#
#      OPTIONS:  ---
# REQUIREMENTS:  
#         BUGS:  Will create duplicate <st> nodes, if there are already some
#                in the input t-file.
#        NOTES:  ---
#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
#      COMPANY:
#      VERSION:  1.0
#      CREATED:  2009/09/16 15:14:58
#===============================================================================

use strict;
use warnings;
use open qw/:utf8 :std/;
use XML::Twig;
use XML::LibXML;
use Carp;

my $st_suffix = qr/\.st\.g?zi?p?$/;
my $t_suffix  = qr/\.t\.g?zi?p?$/;

foreach my $s_filename (@ARGV) {

    # Parse s-file and get s-nodes
    if ( not $s_filename =~ $st_suffix ) {
        carp "$s_filename is not an 'st' file.";
        next;
    }
    my $parser = XML::LibXML->new();
    my $sdoc   = $parser->parse_file($s_filename);
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => 'http://ufal.mff.cuni.cz/pdt/pml/' );

    # Parse t-file and get t-trees
    my $basename = $s_filename =~ s/$st_suffix//;
    my ($t_filename) = <$basename.t*>;
    my $tdoc = $parser->parse_file($t_filename);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => 'http://ufal.mff.cuni.cz/pdt/pml/' );
    my @t_trees = $tdoc->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $tdoc->findnodes('/pml:tdata/pml:head/pml:schema');
    $t_schema->setAttribute( 'href', 'tdata_mwe_schema.xml' );

    # Modify the s-nodes to the correct form and merge them into t-trees
  SNODE:
    foreach my $snode ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st') ) {
        my @tnode_rf   = $snode->findnodes('/pml:t.rf');
        my @tnodes_lms = map $_->unbindNode, @tnode_rf;
        my $tnodes     = $sdoc->createElement('tnodes');
        $tnodes = $snode->appendChild($tnodes);
        map {
            $_->setNodeName('LM');
            $_->replaceDataRegEx( 't#t', 't' );
            $tnodes->appendChild($_)
        } @tnodes_lms;
        my ($s_first_tnode) = $tnodes->findnodes('/pml:LM');

      TNODE: foreach my $troot (@t_trees) {
            no warnings;
            my @lmembers  = $troot->findnodes('//pml:LM');
            my @tnode_ids = map $_->getAttribute(' id '), @lmembers;
            my $match     = grep $_ eq $s_first_tnode, @tnode_ids;
            my ( $mwes_exist, $mwes );
            if ( $troot->exists('/pml:mwes') ) {
                $mwes_exist = 1;
                ($mwes) = $troot->findnodes('/pml:mwes');
            }
            else {
                $mwes = $tdoc->createElement('mwes');
            }
            if ($match) {
                $troot->appendChild($mwes) if not $mwes_exist;
                my $snode_parent = $snode->parentNode;
                $snode = removeChild($snode_parent);
                $mwes->appendChild($snode);
            }
        }

    }
    open( my $out, ' > ', "$s_filename" . ".mwe" );
    print $out $tdoc->toString;
}
