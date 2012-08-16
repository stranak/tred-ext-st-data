
=head1 SDataMerge: the s-data merging library

=head2 AUTHOR:  Pavel Stranak (C<stranak@ufal.mff.cuni.cz>)

The library that handles merging PML s-files into t-files of the
Prague dependency treebank. It also allows to upgrade various legacy versions
of s-data to the current specification.

The documentation below describes the functions of this library. The function 
L<transform()|transform> is the transformation used in the C<TrEd> extension.
=cut

package SDataMerge;

use v5.10;
use strict;
use warnings;
use XML::LibXML;
use URI;
use URI::file;
use List::Util qw(first);

use constant PML_NS => 'http://ufal.mff.cuni.cz/pdt/pml/';

=head2 upgrade_st() - Upgrade (i.e. correct) the st-file, if needed

Original s-files produced during annotations are not valid (according to the
sdata schema) and they need to be transformed. This function checks whether
the s_file needs to be corrected, and does so if needed.

=cut

sub upgrade_st {
    my ($sdoc) = @_;
    my $s_cont = XML::LibXML::XPathContext->new( $sdoc->documentElement() );
    $s_cont->registerNs( pml => PML_NS );
    my @snodes       = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
    my $sdata_format = detect_sdata_format($s_cont);
    if ( $sdata_format == 1 or $sdata_format == 2 )
    {    # old sdata format was detected
        map correct_snode( $sdoc, $s_cont, $_, $sdata_format, '', '', '' ),
          @snodes;
    }
    return $sdoc;
}

=head2 transform() - Merge st-layer information into t-layer

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

    # Modify the s-nodes to the correct form and merge them into t-trees ...
    # ... if there are any s-nodes, of course
    my @snodes = $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st');
    if ( scalar(@snodes) == 0 ) {
        $tdoc = 'empty s-file';
        return $tdoc;
    }
    my $sdata_format = detect_sdata_format($s_cont);
  SNODE:
    foreach my $snode (@snodes) {
        correct_snode( $sdoc, $s_cont, $snode, $sdata_format, $annotator,
                $annot_id_suffix, 'merge' );
        # whan merging, all s-nodes must be corrected: at least renamed and the
        # links to t-nodes must be corrected too, even if the s-file format is
        # current.

        # ID of the first t-node in this s-node
        my $s_first_tnode =
          $s_cont->findvalue( './pml:consists-of/pml:LM[1]/pml:ref', $snode );
        if ( !$s_first_tnode ) {
            warn "There is no such node: consists-of/LM/ref. Skipped.\n";
            next;
        }

      TROOT: foreach my $troot ( @{$t_tree_listref} ) {
            my @nodes_in_this_tree = (
                $t_cont->findnodes( './/pml:children/pml:LM', $troot ),

                # and just in case the t-files use the PML 1-member-list folding
                $t_cont->findnodes( './/pml:children[@id]', $troot ),
            );
            my @tnode_ids = map $_->getAttribute('id'), @nodes_in_this_tree;
            my $match = first { $_ eq $s_first_tnode } @tnode_ids;
            if ($match) {    # The s-node belongs here (to this t-root)
                             # get the 'mwes' node (t-root attr)
                my $mwes;
                if ( $t_cont->exists( './pml:mwes', $troot ) ) {
                    ($mwes) = $t_cont->findnodes( './pml:mwes', $troot );

                    # check for existing annotators, get this annotator the
                    # next unocuppied letter-suffix (B-Z).
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

=head2 detect_sdata_format() - Check the version of an s-file (return BOOL)

Original s-files produced during annotations are not valid (according to the
sdata schema) and they need to be transformed. That is the s-data format
B<v0.1>:
  <st id="s-mf930709-001-l18">
    <lexicon-id>s##person</lexicon-id>
    <t.rf>t#t-mf930709-001-p4s1w22</t.rf>
    <t.rf>t#t-mf930709-001-p4s1w23</t.rf>
  </st>


Then there is a format that is valid, but obsolete. That is the s-data format
B<v0.2>:
  <st id="s-cmpr9410-005-l1">
    <lexicon-id>s#0000024608</lexicon-id>
    <tnode.rfs>
      <LM>t#t-cmpr9410-005-p4s3w1</LM>
      <LM>t#t-cmpr9410-005-p4s3w2</LM>
    </tnode.rfs>
  </st>

The B<new (and output) format> has a MWE structure in the element C<< <consists-of> >>:
  <st id="s-mf930709-001-l70">
    <lexicon-id>s#0000031207</lexicon-id>
    <consists-of>
      <LM>
        <ref>t#t-mf930709-001-p1s1w6</ref>
      </LM>
      <LM>
        <ref>t#t-mf930709-001-p1s1w7</ref>
      </LM>
    </consists-of>
  </st>

This is basically the v0.2 with a possibility to add more information to each
part of a MWE, not just a t-node reference. Other than that, only C<<
<tnode.rfs> >> is renamed to C<< <consists-of> >>.

=cut

sub detect_sdata_format {
    my $s_cont = shift;
    if ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st/pml:t.rf') ) {
        print STDERR
          "Looks like s-data format v0.1. Applying a small transformation.\n";
        return 1;
    }
    elsif ( $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st/pml:tnode.rfs') ) {
        print STDERR
          "Looks like s-data format v0.2. Applying a small transformation.\n";
        return 2;
    }
    elsif ( not $s_cont->findnodes('/pml:sdata/pml:wsd/pml:st') ) {
        print STDERR "The s-data file contains no st-node.\n";
        return;
    }
    elsif (
        $s_cont->findnodes(
            '/pml:sdata/pml:wsd/pml:st/pml:consists-of/pml:LM/pml:ref')
      )
    {   
        print STDERR "Looks like a valid s-data file.\n";
        return 0;
    }
    else {
        print STDERR "Looks like an invalid s-data file.\n";
        return -1;
    }
}

=head2 get_t_trees() - Find the relevant t-file for this st-file

Gets DOM and XPath context of an st-file and returns information about
tectogrammatical file that this st-file will be merged into.

First candidate is a C<*.t.mwe> file of the same basename, i.e. a t-layer
file that has already been merged with some st-file. This is done to merge
multiple annotations into the t.mwe file. Only if this file dosn't yet
exist, the original PDT t-file is taken.

The function returns a list of t-trees, DOM of the t-document, its XPath
context and name of its PML schema (to be modified for t.mwe file).

In case of merging with an existing t.mwe file the existing s-node IDs are
checked and a unique single-letter suffix for this annotator (to be added to
his s-node IDs) is returned as the last argument. The first annotator has no
suffix. The second one gets C<B>, etc.

B<Warning:> It is not advisable to keep bot compressed and uncompressed t.mwe
files in the same directory. Should they be there the behaviour if as follows:
The uncompressed t.mwe file has a precedence and so it is chosen for merging.
However the output can still end up in the t.mwe.gz file. This depends on the
caller script that uses this library!

B<Warning:> If a single document is merged twice, this functon will generate a
unique suffix each time and the duplicate s-nodes are generated, only with
unique ID, due to the new suffix.

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

    # Take t.mwe(.gz) instead, if it exists!
    my $t_mwe_file_URI = $t_file_URI;
    $t_mwe_file_URI =~ s/t\.gz$/t\.mwe/;
    my $t_mwe_file_abs_path = $t_mwe_file_URI;
    $t_mwe_file_abs_path =~ s{file://}{};
    $t_file_URI =
        -s $t_mwe_file_abs_path         ? $t_mwe_file_URI
      : -s $t_mwe_file_abs_path . ".gz" ? $t_mwe_file_URI . ".gz"
      :                                   $t_file_URI;

    my $parser = XML::LibXML->new();
    $parser->keep_blanks(0);
    my $tdoc   = $parser->parse_file($t_file_URI);
    my $t_cont = XML::LibXML::XPathContext->new( $tdoc->documentElement() );
    $t_cont->registerNs( pml => PML_NS );
    my @t_roots = $t_cont->findnodes('/pml:tdata/pml:trees/pml:LM');
    my ($t_schema) = $t_cont->findnodes('/pml:tdata/pml:head/pml:schema');

    # s-node IDs are unique only for a given annotator.
    # So they can conflict, if merging several annotators' s-nodes.
    # So, if we are taking an existing tmwe-file:
    my $annot_id_suffix = '';
    if ( -s $t_mwe_file_abs_path ) {

        # 1) get the s-node (MWE) IDs already in the t-file.
        my @this_file_mwe_ids = ();
        foreach my $t_root (@t_roots) {
            my @mwes = $t_cont->findnodes( 'pml:mwes/pml:LM', $t_root );
            my @this_tree_mwe_ids = map { $_->getAttribute('id') } @mwes;
            push @this_file_mwe_ids, @this_tree_mwe_ids;
        }

        # 2) check for the last annotator-suffix used.
        # FRAGILE: This relis on the fact that PDT IDs don't end with letters.
        my %seen;
        my @suff = sort
            grep { !$seen{$_}++ }
            grep { /[B-Z]/ }
            map  { $_ = chop }
                @this_file_mwe_ids;
        if (@suff) {
            print STDERR "MWE annot. suffixes used: ", join(', ', @suff), "\n";
        } else {
            print STDERR "MWEs present, but no parallel annotation so far. "
                . "(I.e. 2nd annotator is being added now.)\n";
        }
        $annot_id_suffix = pop @suff;

        # 3) get the next letter and set it as the suffix
        # for this s-file's annotator
        given ($annot_id_suffix) {
            when (undef) {

                # an undef as the "last annotator's suffix" means that
                # it was the first annotator. The next one (2nd) will be "B".
                $annot_id_suffix = 'B';
                print STDERR
                  "This annotator's MWE ID suffix: $annot_id_suffix\n";
            }
            when (/[B-Y]/) {
                $annot_id_suffix = chr( ord($annot_id_suffix) + 1 );
                print STDERR
                  "This annotator's MWE ID suffix: $annot_id_suffix\n";
            }
            when ( $_ eq 'Z' ) {
                die "There are 25 annotations already! We do not support more.";
            }
            default {
                die
"mwe ID ending in something other than number or [B-Z]: \"$annot_id_suffix\"";
            }
        }
    }

    return ( \@t_roots, $tdoc, $t_cont, $t_schema, $annot_id_suffix );
}

=head2 correct_snode() - Correct the s-node into a valid form 

Transform the list of references to t-nodes in the st-node into the valid
format.

If the function is called in the context of merging st-layer into t-layer, it
also: 

=over 2

=item *

Removes C<t#> prefix from t-node refs, so that they remain valid when they
are moved directly into the resulting (t-mwe) t-file, and

=item *

Gives each s-node (C<mwes/LM> now) ID a suffix, so that s-node IDs are unique
even in case we merge several annotators' s-nodes into one t-tree. The first
annotator does not get a prefix, because it is not needed.

=back

=cut

sub correct_snode {
    my ( $sdoc, $s_cont, $snode, $sdata_format, $annotator, $annot_suffix,
        $merge_st_into_t )
      = @_;

    # Modify the s-node to the correct form:
    # if the s-file is in the old (original) format,
    # the t-node refs in a s-node must be changed to a proper PML list
    if ($sdata_format ==1 or $sdata_format == 2) {
        my $consists_of = $sdoc->createElementNS( PML_NS, 'consists-of' );
        $consists_of = $snode->appendChild($consists_of);
        my @tnode_rf;
        if ( $sdata_format == 1 ) {
            @tnode_rf = $s_cont->findnodes( './pml:t.rf', $snode );
        }
        elsif ( $sdata_format == 2 ) {
            @tnode_rf = $s_cont->findnodes( './pml:tnode.rfs/pml:LM', $snode );
        }
        map {
            $_->unbindNode;
            $_->setNodeName('ref');
            my $LM = $sdoc->createElementNS( PML_NS, 'LM' );
            $consists_of->appendChild($LM);
            $LM->appendChild($_);
        } @tnode_rf;
        if ( $sdata_format == 2 ) {
            ${$s_cont->findnodes( './pml:tnode.rfs', $snode )}[0]->unbindNode;
        }
    }
    elsif ( $sdata_format == 0 ) {
        # current format, nothing to do here
    }
    else {
        warn "Unknown sdata format, neither 0.1, nor 0.2, nor current";
        return -1;
    }

    # and now, if it is to be be merged into t-layer:
    if ($merge_st_into_t) {
        $snode->setAttribute( 'annotator', "$annotator" );
        $snode->setNodeName('LM');

        # add the annotator-specific suffix to the s-node ID
        # see the function get_t_trees() for its setting.
        # It is an empty string if this is the first annotator.
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

