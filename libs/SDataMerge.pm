#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
package SDataMerge;

use strict;
use warnings;
use XML::LibXML;
use URI;
use URI::file;
use List::Util qw(first);

use constant PML_NS => 'http://ufal.mff.cuni.cz/pdt/pml/';

=head1 upgrade_st() - Upgrade (i.e. correct) the st-file, if needed

 Original s-files produced during annotations are not valid (according to the
 sdata schema) and they need to be transformed. This function checks whether
 the s_file needs to be corrected, and does so if needed.
=cut

sub upgrade_st {
    my ($sdoc) = @_;
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
    map correct_snode( $sdoc, $s_cont, $_, 'yes' ), @snodes
      if is_sfile_format_old($s_cont);
    return $sdoc;
}

=head1 transform() - Merge st-layer information into t-layer

 This is the main merging function.
=cut

sub transform {
    my ($sdoc) = @_;
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my $annotator = $s_cont->findvalue(
        '/pml:sdata/pml:meta/pml:annotation_info/pml:annotator');
    $annotator =~ s/.*?(\w+)$/$1/;

    my ( $t_tree_listref, $tdoc, $t_cont, $t_schema ) =
      get_t_trees( $sdoc, $s_cont );
    $t_schema->setAttribute( 'href', 'tdata_mwe_schema.xml' );

    # Modify the s-nodes to the correct form and merge them into t-trees ...
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');

    # ... if there are any s-nodes, of course
    if ( scalar(@snodes) == 0 ) {
        $tdoc = 'empty s-file';
        return $tdoc;
    }

    my $is_sfile_old = is_sfile_format_old($s_cont);
  SNODE:
    foreach my $snode (@snodes) {
        correct_snode( $sdoc, $s_cont, $snode, $is_sfile_old, $annotator,
            'merge' );

        # ID of the first t-node in this s-node
        my $s_first_tnode =
          $s_cont->findvalue( './pml:tnode.rfs/pml:LM[1]', $snode );

      TROOT: foreach my $troot ( @{$t_tree_listref} ) {
            my @nodes_in_this_tree =
              $t_cont->findnodes( './/pml:children/pml:LM', $troot );
            my @tnode_ids = map $_->getAttribute('id'), @nodes_in_this_tree;
            my $match = first { $_ eq $s_first_tnode } @tnode_ids;
            if ($match) {    # The s-node belongs here (to this t-root)
                             # get the 'mwes' node (t-root attr)
                my $mwes;
                if ( $t_cont->exists( './pml:mwes', $troot ) ) {
                    ($mwes) = $t_cont->findnodes( './pml:mwes', $troot );
                }
                else {
                    $mwes = $tdoc->createElementNS( PML_NS, 'mwes' );
                    $troot->insertBefore( $mwes, $troot->firstChild );
                }

                # cut the s-node from s-file and attach it here
                my $snode_parent = $snode->parentNode;
                $snode = $snode_parent->removeChild($snode);
                $mwes->appendChild($snode);
            }
        }
    }
    return $tdoc;
}

=head1 is_sfile_format_old() - Check the version of an s-file (return BOOL)

 Original s-files produced during annotations are not valid (according to the
 sdata schema) and they need to be transformed.
=cut

sub is_sfile_format_old {
    my $s_cont = shift;
    if ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st/pml:t.rf') ) {
        print STDERR
"Looks like old, not valid s-data file. I will transform its contents.\n";
        return 1;
    }
    elsif ( not $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st') ) {
        print STDERR "The s-data file contains no st-node.\n";
        return;
    }
    else {
        print STDERR "Looks like a valid s-data file.\n";
        return 0;
    }
}

=head1 get_t_trees() - Find the relevant t-trees for this st-doc

Gets DOM and XPath context of an st-file and returns information about
tectogrammatical file that this st-file will be merged into.

First candidate is a *.t.mwe.gz file of the same basename, i.e. a t-layer
file that has already been merged with some st-file. This is done to merge
multiple annotations into the t.mwe.gz file. Only if this file dosn't yet
exist, the original PDT t-file is taken.

The function returns a list of t-trees, DOM of the t-document, its XPath
context and name of its PML schema (to be modified for t.mwe file).
=cut

sub get_t_trees {
    my ( $sdoc, $s_cont ) = @_;

    # Parse t-file and get t-trees
    my $t_filename = $s_cont->findvalue(
'/pml:sdata/pml:head[1]/pml:references[1]/pml:reffile[@name="tdata"]/@href'
    );
    my $t_file_URI =
      URI->new_abs( $t_filename,
        URI->new( $sdoc->URI )->abs( URI::file->cwd ) );

    # Take t.mwe.gz instead, if it exists!
    my $t_mwe_file_URI = $t_file_URI;
    $t_mwe_file_URI =~ s/t\.gz$/t\.mwe\.gz/;
    my $t_mwe_file_abs_path = $t_mwe_file_URI;
    $t_mwe_file_abs_path =~ s{file://}{};
    $t_file_URI = -s $t_mwe_file_abs_path ? $t_mwe_file_URI : $t_file_URI;

    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $tdoc   = $parser->parse_file($t_file_URI);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => PML_NS );
    my @t_trees = $t_cont->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $t_cont->findnodes('/pml:tdata/pml:head/pml:schema');
    return ( \@t_trees, $tdoc, $t_cont, $t_schema );
}

=head1 correct_snode() - Correct the s-node into a valid form 

Transform the list of references to t-nodes in the st-node into the valid
format.

If the function is called in the context of merging st-layer into t-layer, it
also removes t# prefix from t-node refs, so that they remain valid when they
are moved directly into the resulting (t-mwe) t-file.
=cut

sub correct_snode {
    my ( $sdoc, $s_cont, $snode, $is_sfile_old, $annotator, $merge_st_into_t ) =
      @_;

    # Modify the s-node to the correct form:
    # if the s-file is in the old (original) format,
    # the t-node refs in a s-node must be changed to a proper PML list
    if ($is_sfile_old) {
        my $tnode_rfs = $sdoc->createElementNS( PML_NS, 'tnode.rfs' );
        $tnode_rfs = $snode->appendChild($tnode_rfs);
        my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
        map {
            $_->unbindNode;
            $_->setNodeName('LM');
            $tnode_rfs->appendChild($_);
        } @tnode_rf;
    }

    # and now, if it is to be be merged into t-layer:
    if ($merge_st_into_t) {
        $snode->setAttribute( 'annotator', "$annotator" );
        $snode->setNodeName('LM');

        # correct the t-node refs (not stand-off any more)
        map {
            my ($textchild) = $_->childNodes;
            $textchild->replaceDataRegEx( 't#t', 't' )
        } $s_cont->findnodes( './pml:tnode.rfs/pml:LM', $snode );

    }
    return;
}

1;

