component extends="farcry.core.packages.types.types" displayName="Algolia Content Type" {

	property name="contentType" type="string" required="false" 
		ftSeq="1" ftWizardStep="" ftFieldset="" ftLabel="Content Type"
		ftHint="The content type being indexed";

	property name="datetimeBuiltTo" type="date" required="false" 
		ftSeq="2" ftWizardStep="" ftFieldset="" ftLabel="Built to Date" 
		ftType="datetime" ftDefaultType="Evaluate" ftDefault="now()" 
		ftDateFormatMask="dd mmm yyyy" ftTimeFormatMask="hh:mm tt" ftShowTime="true"
		ftHint="Used as a reference of the last indexed item.";

	property name="configSignature" type="string" required="false" 
		ftSeq="3" ftWizardStep="" ftFieldset="" ftLabel="Config Signature"
		ftHint="A hash of the current configuration for this content type. Can be used to determine if the config has changed, and this type needs to be reindexed.";

}