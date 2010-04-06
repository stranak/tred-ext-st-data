# vim: set syntax=perl: 


{
package PML_ST_Data;

BEGIN { import TredMacro; }
sub detect {
    return (
    (PML::SchemaName()||'') =~ /tdata/ and
     PML::Schema->find_type_by_path('!t-root.type/mwes')  ? 1 : 0);
}

unshift @TredMacro::AUTO_CONTEXT_GUESSING, sub {
  my ($hook)=@_;
  my $resuming = ($hook eq 'file_resumed_hook');
  my $current = CurrentContext();
  if (detect()) {
    return __PACKAGE__;
  }
  return;
};

sub allow_switch_context_hook {
  return 'stop' unless detect();
}
sub switch_context_hook {
  if(PML::SchemaName() eq 'tdata' and
     PML::Schema->find_type_by_path('!t-root.type/mwes')){
    SetCurrentStylesheet('HYDT');
  }else{ # SchemaName eq 'hydtmorph'
    SetCurrentStylesheet('hydt-morph');
  }
  Redraw() if GUI();
}

#binding-context PML_ST_Data

#include <contrib/support/fold_subtree.inc>

#bind fold_subtree_toggle to space menu Fold/unfold current subtree (toggle)
#bind fold_subtree_unfold_all to Ctrl+space menu Unfold all in the current subtree


sub after_redraw_hook {
  my @stnodes =ListV($root->attr('mwes/annotator/#content/st'));
  foreach my $st (@stnodes){
    my @group =  map { PML_T::GetNodeByID($_) } ListV($st->{'tnode.rfs'});
    TrEd::NodeGroups::draw_groups( $grp, [[@group]], {colors => ['#9FF'], stipples => TrEd::NodeGroups::dense_stipples($grp)} );
  }
}
}
1;
