#       AUTHOR:  Pavel Stranak (stranak@ufal.mff.cuni.cz),
package SDataMerge;

use strict;
use warnings;
use XML::LibXML;
use URI;
use URI::file;
use List::Util qw(first);

use constant PML_NS => 'http://ufal.mff.cuni.cz/pdt/pml/';

sub upgrade_st {
    my ($sdoc) = @_;
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my @snodes    = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
    my $sfile_old = is_sfile_format_old($s_cont);
  SNODE:
    foreach my $snode (@snodes) {
        if ($sfile_old) {
            correct_snode( $sdoc, $s_cont, $snode );
        }
    }
    return $sdoc;
}

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

    # Modify the s-nodes to the correct form and merge them into t-trees
    my @snodes    = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
    my $sfile_old = is_sfile_format_old($s_cont);
  SNODE:
    foreach my $snode (@snodes) {
        if ($sfile_old) {
            correct_snode( $sdoc, $s_cont, $snode, 'merge' );
        }
        else {
            my @tnode_rf =
              $s_cont->findnodes( './pml:tnode.rfs/pml:LM', $snode );
            map {
                my ($textchild) = $_->childNodes;
                $textchild->replaceDataRegEx( 't#t', 't' );
            } @tnode_rf;
        }

        # ID of the first t-node in this s-node
        my $s_first_tnode =
          $s_cont->findvalue( './pml:tnode.rfs/pml:LM[1]', $snode );

      TROOT: foreach my $troot ( @{$t_tree_listref} ) {
            my @nodes_in_this_tree =
              $t_cont->findnodes( './/pml:children/pml:LM', $troot );
            my @tnode_ids = map $_->getAttribute('id'), @nodes_in_this_tree;
            my $match = first { $_ eq $s_first_tnode } @tnode_ids;
            if ($match) {
                my $annotators_mwes =
                  get_annot_mwes( $tdoc, $t_cont, $troot, $annotator );
                my $snode_parent = $snode->parentNode;
                $snode = $snode_parent->removeChild($snode);
                $annotators_mwes->appendChild($snode);
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
        print STDERR
"Looks like old, not valid s-data file. I will transform its contents.\n";
        return 1;
    }
    else {
        print STDERR "Looks like a valid s-data file.\n";
        return 0;
    }
}

sub get_annot_mwes {
    my ( $tdoc, $t_cont, $troot, $annotator ) = @_;
    my $mwes;
    if ( $t_cont->exists( './pml:mwes', $troot ) ) {
        ($mwes) = $t_cont->findnodes( './pml:mwes', $troot );
    }
    else {
        $mwes = $tdoc->createElementNS( PML_NS, 'mwes' );
        $troot->insertBefore( $mwes, $troot->firstChild );
    }

    # get the <annotator> element of this t-root for the
    # $annotator (from the s-file). Create it, if it doesn't exist.
    my $annot_mwes;
    if ( $t_cont->exists( './pml:annotator', $mwes ) ) {
        my @annotators = $t_cont->findnodes( './pml:annotator', $mwes );
        $annot_mwes =
          first { $_->getAttribute('name') =~ $annotator } @annotators;
    }
    if ( not $annot_mwes )
    {    # an element for this annotator's MWEs doesn't exist
        $annot_mwes = $tdoc->createElementNS( PML_NS, 'annotator' );
        my $name_attr = $tdoc->createAttribute( 'name', $annotator );
        $name_attr = $annot_mwes->addChild($name_attr);
        $mwes->insertBefore( $annot_mwes, $mwes->firstChild );
    }
    return $annot_mwes;
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
    print STDERR "\n>>$t_file_URI\n\n";
  
    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $tdoc   = $parser->parse_file($t_file_URI);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => PML_NS );
    my @t_trees = $t_cont->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $t_cont->findnodes('/pml:tdata/pml:head/pml:schema');
    return ( \@t_trees, $tdoc, $t_cont, $t_schema );
}

sub correct_snode {
    my ( $sdoc, $s_cont, $snode, $merge_st_into_t ) = @_;

    # Modify the s-node to the correct form
    my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
    map $_->unbindNode, @tnode_rf;
    my $tnode_rfs = $sdoc->createElementNS( PML_NS, 'tnode.rfs' );
    $tnode_rfs = $snode->appendChild($tnode_rfs);
    map {
        $_->setNodeName('LM');
        my ($textchild) = $_->childNodes;
        $textchild->replaceDataRegEx( 't#t', 't' ) if $merge_st_into_t;
        $tnode_rfs->appendChild($_);
    } @tnode_rf;
    return ( $sdoc, $s_cont, $snode );
}

1;

