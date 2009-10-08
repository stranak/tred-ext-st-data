#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  merge-s-and-t-layer.pl
#
#        USAGE:  ./merge-s-and-t-layer.pl <st-files>
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

my $st_suffix = qr/\.st\.g?zi?p?$/;
my $t_suffix  = qr/\.t\.g?zi?p?$/;

foreach my $s_filename (@ARGV) {

    # Parse s-file and get s-nodes
    if ( not $s_filename =~ $st_suffix ) {
        warn "$s_filename is not an 'st' file.";
        next;
    }
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $sdoc   = $parser->parse_file($s_filename);
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => 'http://ufal.mff.cuni.cz/pdt/pml/' );

    # Parse t-file and get t-trees
    $s_filename =~ s/$st_suffix//;
    my ($t_filename) = <$s_filename.t*>;
    my $tdoc = $parser->parse_file($t_filename);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => 'http://ufal.mff.cuni.cz/pdt/pml/' );
    my @t_trees = $t_cont->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $t_cont->findnodes('/pml:tdata/pml:head/pml:schema');
    $t_schema->setAttribute( 'href', 'tdata_mwe_schema.xml' );

    # Modify the s-nodes to the correct form and merge them into t-trees
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
  SNODE:
    foreach my $snode (@snodes) {
        my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
        map $_->unbindNode, @tnode_rf;
        my $tnodes = $sdoc->createElement('tnodes');
        $tnodes = $snode->appendChild($tnodes);
        map {
            $_->setNodeName('LM');
            my ($textchild) = $_->childNodes;
            $textchild->replaceDataRegEx( 't#t', 't' );
            $tnodes->appendChild($_);
        } @tnode_rf;
        my ($s_first_tnode) = map $_->toString,
          $s_cont->findnodes( './pml:LM/text()', $tnodes );

      TNODE: foreach my $troot (@t_trees) {
            no warnings;
            my @lmembers = $t_cont->findnodes( './/pml:LM', $troot );
            my @tnode_ids = map $_->getAttribute('id'), @lmembers;
            my ($match) = grep $_ eq $s_first_tnode, @tnode_ids;
            my ( $mwes_exist, $mwes );
            if ($match) {
                if ( $t_cont->exists( './mwes', $troot ) ) {
                    $mwes_exist = 1;
                    ($mwes) = $t_cont->findnodes( './mwes', $troot );
                }
                else {
                    $mwes = $tdoc->createElement('mwes');
                    $troot->insertBefore( $mwes, $troot->firstChild );
                }
                my $snode_parent = $snode->parentNode;
                $snode = $snode_parent->removeChild($snode);
                $mwes->appendChild($snode);
            }
        }
    }
    my $tmwe_filename = $t_filename . ".mwe.gz";
    $tdoc->setCompression('6');
    $tdoc->toFile( $tmwe_filename, 1 );
}
