<?xml version="1.0" encoding="utf-8"?>
<pmlbackend
  xmlns="http://ufal.mff.cuni.cz/pdt/pml/"
  xmlns:xi="http://www.w3.org/2001/XInclude">
  <head>
    <schema href="pmlbackend_conf_schema.xml"/>
  </head>
  <transform_map>
      <transform id="sdata" root="sdata" ns="http://ufal.mff.cuni.cz/pdt/pml/">
        <in type="perl" command="require SDataMerge; return SDataMerge::transform(@_);"/>
      </transform>
      <!--

      other possiblity

      <transform id="sdata2" root="sdata" ns="http://ufal.mff.cuni.cz/pdt/pml/">
        <in type="shell" command="merge-s-and-t-layer.pl">
	  <param name="-S"></param>
	</in>
      </transform>

      -->
  </transform_map>
</pmlbackend>
