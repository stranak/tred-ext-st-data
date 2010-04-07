# vim: set syntax=perl:

{

    package PML_ST_Data;
#     use strict;

    BEGIN { import TredMacro; }

    sub detect {
        return ( ( PML::SchemaName() || '' ) =~ /tdata/
              and PML::Schema->find_type_by_path('!t-root.type/mwes') ? 1 : 0 );
    }

    unshift @TredMacro::AUTO_CONTEXT_GUESSING, sub {
        my ($hook) = @_;
        my $resuming = ( $hook eq 'file_resumed_hook' );
        my $current = CurrentContext();
        if ( detect() ) {
            return __PACKAGE__;
        }
        return;
    };

# following MUST NOT be indented!
#binding-context PML_ST_Data

#include <contrib/support/fold_subtree.inc>

#bind fold_subtree_toggle to space menu Fold/unfold current subtree (toggle)
#bind fold_subtree_unfold_all to Ctrl+space menu Unfold all in the current subtree

    sub allow_switch_context_hook {
        return 'stop' unless detect();
    }

    sub switch_context_hook {
        PML_T::CreateStylesheets() && SetCurrentStylesheet('PML_T_Compact');
        Redraw() if GUI();
    }

    sub after_redraw_hook {
    # TODO ruzny stipple pro ruzne anotatory.
        my %mwe_colours = (
	    semlex      => 'maroon',
	    person      => 'olive drab',
	    institution => 'hot pink',
	    location    => 'Turquoise1',
	    object      => 'plum',
	    address     => 'light slate blue',
	    time        => 'lime green',
	    biblio      => '#8aa3ff',
	    foreign     => '#8a535c',
	    other       => 'orange1',
        );
        my @stnodes = ListV( $root->attr('mwes/annotator/#content/st') );
        foreach my $mwe_type ( keys %mwe_colours ) {
	 my @these_mwes = $mwe_type eq 'semlex'                    ? 
		 grep { $_->{'lexicon-id'} =~ /^s#\d+$/ } @stnodes :
		 grep { $_->{'lexicon-id'} eq "s##$mwe_type" } @stnodes;
            foreach my $st (@these_mwes) {
                my @group =
                  map { PML_T::GetNodeByID($_) } ListV( $st->{'tnode.rfs'} );
                TrEd::NodeGroups::draw_groups(
                    $grp,
                    [ [@group] ],
                    {
                        colors   => [ $mwe_colours{$mwe_type} ],
			stipples => ['dense1']
			# group_line_width => 30, # default
                    }
                );
            }
        }
    }

}
1;
