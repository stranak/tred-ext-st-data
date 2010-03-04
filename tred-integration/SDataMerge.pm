#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
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
    my $t_filename =
      $s_cont->findvalue(
'/pml:sdata/pml:head[1]/pml:references[1]/pml:reffile[@name="tdata"]/@href'
      );
    my $t_file_URI =
      URI->new_abs( $t_filename,
        URI->new( $sdoc->URI )->abs( URI::file->cwd ) );

    # Parse t-file and get t-trees
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $tdoc   = $parser->parse_file($t_file_URI);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => PML_NS );
    my @t_trees = $t_cont->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $t_cont->findnodes('/pml:tdata/pml:head/pml:schema');

    $t_schema->setAttribute( 'href', 'tdata_mwe_schema.xml' );

    # Modify the s-nodes to the correct form and merge them into t-trees
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
  SNODE:
    foreach my $snode (@snodes) {
        my $tnodes; # the t-nodes in this s-node
        if ( sfile_format_is_old($s_cont) ) {
            warn "$sdoc looks like old, not valid, s-data file. I will transform
                its contents.\n";
            # Modify the s-node to the correct form
            my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
            map $_->unbindNode, @tnode_rf;
            $tnodes = $sdoc->createElementNS( PML_NS, 'tnode.rfs' );
            $tnodes = $snode->appendChild($tnodes);
            map {
                $_->setNodeName('LM');
                my ($textchild) = $_->childNodes;
                $textchild->replaceDataRegEx( 't#t', 't' );
                $tnodes->appendChild($_);
            } @tnode_rf;
        }
        else {
            warn "$sdoc looks like a valid s-data file.\n";
        # only change references into a 't' file to references into 'this' file
            $tnodes = $s_cont->findnodes( './pml:tnode.rfs', $snode );
            my @tnode_rf =
              $s_cont->findnodes( './pml:tnode.rfs/pml:LM', $snode );
            map {
                my ($textchild) = $_->childNodes;
                $textchild->replaceDataRegEx( 't#t', 't' );
            } @tnode_rf;
        }

        # ID of the first t-node in this s-node
        my ($s_first_tnode) = map $_->toString,
          $s_cont->findnodes( './pml:LM/text()', $tnodes );

      TNODE: foreach my $troot (@t_trees) {
            no warnings;
            my @lmembers = $t_cont->findnodes( './/pml:LM', $troot );
            my @tnode_ids = map $_->getAttribute('id'), @lmembers;
            my ($match) = grep $_ eq $s_first_tnode, @tnode_ids;
            my ( $mwes_exist, $mwes );
            if ($match) {
                if ( $t_cont->exists( './pml:mwes', $troot ) ) {
                    $mwes_exist = 1;
                    ($mwes) = $t_cont->findnodes( './pml:mwes', $troot );
                }
                else {
                    $mwes = $tdoc->createElementNS( PML_NS, 'mwes' );
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

#Check the version of an s-file. Original s-files produced during annotations
#are not valid (according to the sdata schema) and they need to be transformed.
sub sfile_format_is_old {
    my $s_cont = shift;
    if ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st/pml:t.rf') ) {
        return 1;
    }
    else { return 0 }
}

1;

