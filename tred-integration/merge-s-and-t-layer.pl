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
# REQUIREMENTS:  S-files and t-files uncompressed, a,m,w files gzipped.
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
    my @t_tree = $tdoc->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $tdoc->findnodes('/pml:tdata/pml:head/pml:schema');
    $t_schema->setAttribute('href', 'tdata_mwe_schema.xml');

    # Modify the s-nodes to the correct form and merge them into t-trees
  SNODE:
    foreach my $snode ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st') ) {

        my (
        # twig - start - to rewrite
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

      TNODE: foreach my $troot (@t_tree) {
            no warnings;
            my @lmembers  = $troot->descendants('LM');
            my @tnode_ids = map { $_->att('id') } @lmembers;
            my $match     = grep { $_ eq $s_first_tnode } @tnode_ids;
            my ( $mwes_exist, $mwes );
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
            }
        }

        # twig - end
    }
    open( my $out, '>', "$s_filename" . ".mwe" );
    print $out $tdoc->toString;
}
