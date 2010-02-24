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

package SDataMerge;

use strict;
use warnings;
use XML::LibXML;
use URI;
use URI::file;

use constant PML_NS => 'http://ufal.mff.cuni.cz/pdt/pml/';

sub transform {
    my ($sdoc) = @_;

    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my $t_filename = $s_cont->findvalue('/pml:sdata/pml:head[1]/pml:references[1]/pml:reffile[@name="tdata"]/@href');
    my $t_file_URI = URI->new_abs($t_filename,URI->new($sdoc->URI)->abs(URI::file->cwd));

    # Parse t-file and get t-trees
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $tdoc = $parser->parse_file($t_file_URI);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => PML_NS );
    my @t_trees = $t_cont->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $t_cont->findnodes('/pml:tdata/pml:head/pml:schema');
    $t_schema->setAttribute( 'href', 'tdata_mwe_schema.xml' );

    # Modify the s-nodes to the correct form and merge them into t-trees
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
  SNODE:
    foreach my $snode (@snodes) {
        my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
        map $_->unbindNode, @tnode_rf;
        my $tnodes = $sdoc->createElementNS(PML_NS, 'tnodes');
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
                    $mwes = $tdoc->createElementNS(PML_NS, 'mwes');
                    $troot->insertBefore( $mwes, $troot->firstChild );
                }
                my $snode_parent = $snode->parentNode;
                $snode = $snode_parent->removeChild($snode);
                $mwes->appendChild($snode);
            }
        }
    }
    return $tdoc;
  }

1;

