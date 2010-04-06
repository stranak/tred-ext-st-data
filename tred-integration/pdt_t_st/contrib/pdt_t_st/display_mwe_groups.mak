# vim: set syntax=perl: 


{
package PML_ST_Data;

BEGIN { import TredMacro; }

#binding-context HYDT

#include <contrib/support/fold_subtree.inc>

#bind fold_subtree_toggle to space menu Fold/unfold current subtree (toggle)
#bind fold_subtree_unfold_all to Ctrl+space menu Unfold all in the current subtree


sub after_redraw_hook {
  my @stnodes =ListV($root->attr('mwes/annotator/#content/st'));
  foreach my $st (@stnodes){
    my @group =  map { PML_T::GetNodeByID($_) } ListV($st->{'tnode.rfs'});
    TrEd::NodeGroups::draw_groups( $grp, [[@group]], {colors => ['#9FF'], stipples => TrEd::NodeGroups::dense_stipples($grp)} );
  }
  print STDERR "\n>>>My hook loaded.\n";
}
}
1;
