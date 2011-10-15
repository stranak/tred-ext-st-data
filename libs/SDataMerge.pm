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
    map correct_snode( $sdoc, $s_cont, $_, 'yes', '', '', '' ), @snodes
      if is_sfile_format_old($s_cont);
    return $sdoc;
}

=head1 transform() - Merge st-layer information into t-layer

 This is the main merging function.
=cut

sub transform {
    my ( $sdoc, $s_filename ) = @_;
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my $annot_string = $s_cont->findvalue(
        '/pml:sdata/pml:meta/pml:annotation_info/pml:annotator');
    my $annotator = $annot_string;
    $annotator =~ s/.*?(\w+)\W*$/$1/;

    # Warning with a filename and the node "annotator" from the
    # s-file metadata, in case we can't get a word by parsing the
    # element
    if ( not $annotator ) {
        if ( not $s_filename ) {

            # the function is being used interactively from TrEd
            $s_filename = 'this file';
        }
        print STDERR
"No annotator name in $s_filename\'s annotator node: \'$annot_string\'.";
    }

    my ( $t_tree_listref, $tdoc, $t_cont, $t_schema, $annot_id_suffix ) =
      get_t_trees( $sdoc, $s_cont );
    $t_schema->setAttribute( 'href', 'tdata_mwe_schema.xml' );

    # if this t-file does not yet include any MWE annotations, this annotator
    # is the first. Thus his IDs get the suffix 'A'.
    $annot_id_suffix = 'A' if not $annot_id_suffix;

    # Modify the s-nodes to the correct form and merge them into t-trees ...
    # ... if there are any s-nodes, of course
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
    if ( scalar(@snodes) == 0 ) {
        $tdoc = 'empty s-file';
        return $tdoc;
    }
    my $is_sfile_old = is_sfile_format_old($s_cont);
  SNODE:
    foreach my $snode (@snodes) {
        correct_snode( $sdoc, $s_cont, $snode, $is_sfile_old, $annotator,
            $annot_id_suffix, 'merge' );

        # ID of the first t-node in this s-node
        my $s_first_tnode =
          $s_cont->findvalue( './pml:consists-of/pml:LM[1]/pml:ref', $snode );

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
          "Looks like s-data format v0.1. Applying a small transformation.\n";
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

=head1 get_t_trees() - Find the relevant t-file for this st-file

Gets DOM and XPath context of an st-file and returns information about
tectogrammatical file that this st-file will be merged into.

First candidate is a *.t.mwe.gz file of the same basename, i.e. a t-layer
file that has already been merged with some st-file. This is done to merge
multiple annotations into the t.mwe.gz file. Only if this file dosn't yet
exist, the original PDT t-file is taken.

The function returns a list of t-trees, DOM of the t-document, its XPath
context and name of its PML schema (to be modified for t.mwe file).

In case of merging with an existing t.mwe file the existing s-node IDs are
checked and a unique single-letter suffix for this annotator (to be added to
his s-node IDs) is returned as the last argument.

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

    # s-node IDs are unique only for a given annotator.
    # So they can conflict, if merging several annotators' s-nodes.
    # So, if we are taking an existing tmwe-file:
    my $annot_id_suffix;
    if ( -s $t_mwe_file_abs_path ) {

        # 1) get the s-node (MWE) IDs already in the t-file.
        my @this_file_mwe_ids = ();
        foreach my $t_tree (@t_trees) {
            my @mwes = $t_tree->findnodes('pml:mwes/pml:LM');
            my @mwe_ids = map { $_->getAttribute('id') } @mwes;
            push @this_file_mwe_ids, @mwe_ids;
        }

        print STDERR "IDs: ", join ', ', @this_file_mwe_ids, "\n";

        # 2) check for the last annotator-suffix used
        my @suffixes = map chop, grep /[A-Z]$/, @this_file_mwe_ids;
        @suffixes = sort @suffixes;
        print STDERR "SUF: ", join ', ', @suffixes, "\n";
        $annot_id_suffix = pop @suffixes;

        # 3) get the next letter and set it as the suffix for this s-file's
        # annotator
        $annot_id_suffix = chr( ord($annot_id_suffix) + 1 );
        say STDERR "MY ID: $annot_id_suffix";
    }

    return ( \@t_trees, $tdoc, $t_cont, $t_schema, $annot_id_suffix );
}

=head1 correct_snode() - Correct the s-node into a valid form 

Transform the list of references to t-nodes in the st-node into the valid
format.

If the function is called in the context of merging st-layer into t-layer, it
also: 
1) removes t# prefix from t-node refs, so that they remain valid when they
are moved directly into the resulting (t-mwe) t-file, and
2) gives each s-node (mwes/LM now) ID a suffix, so that s-node IDs are unique
even in case we merge several annotators' s-nodes into one t-tree.
=cut

sub correct_snode {
    my ( $sdoc, $s_cont, $snode, $is_sfile_old, $annotator, $annot_suffix,
        $merge_st_into_t )
      = @_;

    # Modify the s-node to the correct form:
    # if the s-file is in the old (original) format,
    # the t-node refs in a s-node must be changed to a proper PML list
    if ($is_sfile_old) {
        my $consists_of = $sdoc->createElementNS( PML_NS, 'consists-of' );
        $consists_of = $snode->appendChild($consists_of);
        my @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
        map {
            $_->unbindNode;
            $_->setNodeName('ref');
            my $LM = $sdoc->createElementNS( PML_NS, 'LM' );
            $consists_of->appendChild($LM);
            $LM->appendChild($_);
        } @tnode_rf;
    }

    # and now, if it is to be be merged into t-layer:
    if ($merge_st_into_t) {
        $snode->setAttribute( 'annotator', "$annotator" );
        $snode->setNodeName('LM');

        # add the annotator-specific suffix to the s-node ID
        # see the function get_t_trees() for its setting
        my $id = $snode->getAttribute('id');
        $id = $id . $annot_suffix;
        $snode->setAttribute( 'id', "$id" );

        # correct the t-node refs (not stand-off any more)
        map {
            my ($textchild) = $_->childNodes;
            $textchild->replaceDataRegEx( 't#t', 't' )
        } $s_cont->findnodes( './pml:consists-of/pml:LM/pml:ref', $snode );

    }
    return;
}

1;

