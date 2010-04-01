#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
package SDataMerge;

use strict;
use warnings;
use XML::LibXML;
use URI;
use URI::file;
use List::Util qw(first);

use constant PML_NS => 'http://ufal.mff.cuni.cz/pdt/pml/';

sub transform {
    my ($sdoc) = @_;
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my $annotator = $s_cont->findvalue(
'/pml:sdata/pml:meta/pml:annotation_info/pml:annotator');
    $annotator =~ s/.*?(\w+)$/$1/;
    print $annotator, "\n";
    my $is_sfile_old = is_sfile_format_old($s_cont);

    my $t_filename = $s_cont->findvalue(
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
        my $tnode_rfs;    # the t-nodes in this s-node
        if ($is_sfile_old) {

            # Modify the s-node to the correct form
            my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
            map $_->unbindNode, @tnode_rf;
            $tnode_rfs = $sdoc->createElementNS( PML_NS, 'tnode.rfs' );
            $tnode_rfs = $snode->appendChild($tnode_rfs);
            map {
                $_->setNodeName('LM');
                my ($textchild) = $_->childNodes;
                $textchild->replaceDataRegEx( 't#t', 't' );
                $tnode_rfs->appendChild($_);
            } @tnode_rf;
        }
        else {

         # only change references into a 't' file to references into 'this' file
            $tnode_rfs = $s_cont->findnodes( './pml:tnode.rfs', $snode );
            my @tnode_rf =
              $s_cont->findnodes( './pml:tnode.rfs/pml:LM', $snode );
            map {
                my ($textchild) = $_->childNodes;
                $textchild->replaceDataRegEx( 't#t', 't' );
            } @tnode_rf;
        }

        # ID of the first t-node in this s-node
        my ($s_first_tnode) = map $_->toString,
          $s_cont->findnodes( './pml:LM/text()', $tnode_rfs );

      TROOT: foreach my $troot (@t_trees) {
#            no warnings;
            my @nodes_in_this_tree = $t_cont->findnodes( './/pml:children/pml:LM', $troot );
            my @tnode_ids = map $_->getAttribute('id'), @nodes_in_this_tree;
#            warn join ', ', @tnode_ids, "\n"; next TROOT;
            my $match = first { $_ eq $s_first_tnode } @tnode_ids;
            if ($match) {
                my $mwes = get_mwes($tdoc, $t_cont, $troot);
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
sub is_sfile_format_old {
    my $s_cont = shift;
    if ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st/pml:t.rf') ) {
        warn
"Looks like old, not valid s-data file. I will transform its contents.\n";
        return 1;
    }
    else {
        warn "Looks like a valid s-data file.\n";
        return 0;
    }
}


sub get_mwes {
    my ($tdoc, $t_cont, $troot) = @_;
    my $mwes;
    if ( $t_cont->exists( './pml:mwes', $troot ) ) {
        ($mwes) = $t_cont->findnodes( './pml:mwes', $troot );
    }
    else {
        $mwes = $tdoc->createElementNS( PML_NS, 'mwes' );
        $troot->insertBefore( $mwes, $troot->firstChild );
    }
    return $mwes;
}

1;

