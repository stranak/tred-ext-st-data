{

    package PML_ST_Data;
    use strict;
    BEGIN { import TredMacro; }

    our %annotator;    
    #This hash and its use in after_redraw_hook() is needed to keep constant
    #order of annotators between trees in files that include multiple
    #annotators' annotations. 


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

    sub get_value_line_hook {
        PML_T::get_value_line_hook(@_);
    }

    sub after_redraw_hook {
# The same colours as those used in the annotation tool sem-ann, 
# except for red for 'real mwes' - i.e. SemLex entries other than NEs
        my %mwe_colours = ( 
            semlex      => 'red', #originally 'maroon'
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
        my @stipples = (qw(dense1 dense2 dense5 dense6));
        foreach my $snode ( ListV( $root->attr('mwes' || '') ) ) {
            my $name = $snode->{annotator};
            $annotator{$name} = (keys %annotator)+ 1 if not $annotator{$name};
            my $mwe_type = $snode->{'lexicon-id'};
            $mwe_type =~ s/^s#//;
            if ($mwe_type =~ /^\d+$/){ $mwe_type = 'semlex' }
            else { $mwe_type =~ s/^#// }
            my @group = map { PML_T::GetNodeByID($_) } ListV( $snode->{'tnode.rfs'} );
            TrEd::NodeGroups::draw_groups(
                $grp,
                [ [@group] ],
                {
                    colors   => [ $mwe_colours{$mwe_type} ],
                    stipples => [ $stipples[ $annotator{$name} -1 ] ]
                }
            );
        }
    }

}
# vim: set ft=perl:

1;
