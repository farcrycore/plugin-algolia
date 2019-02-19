<cfsetting enablecfoutputonly="true">
<!--- @@viewbinding: type --->
<!--- @@fuAlias: push --->

<cftry>
	<cfset stProps = application.fapi.getContentObject(typename=url.pushtype, objectid=url.pushid) />

	<!--- update index --->
	<cfif application.fc.lib.algolia.isIndexable(stProps)>
		<cfset stResult = application.fc.lib.algolia.importIntoIndex(stObject=stProps, operation="updated") />
		<cfset application.fapi.stream(content={ "success":true, "message":"Pushed document to Algolia", "result":stResult }, type="json") />
	<cfelse>
		<cfset application.fapi.stream(content={ "success":true, "message":"Content type is not indexed" }, type="json") />
	</cfif>

	<cfcatch>
		<cfset stErr = application.fc.lib.error.normalizeError(cfcatch) />
		<cfset application.fc.lib.error.logData(stErr) />
		<cfset application.fapi.stream(content={ "success":false, "message":stErr.message, "detail":stErr }, type="json") />
	</cfcatch>
</cftry>

<cfsetting enablecfoutputonly="false">