<cfsetting enablecfoutputonly="true" requesttimeout="10000">
<!--- @@viewBinding: any --->

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfparam name="url.mode" default="upload" />

<cfif url.mode eq "initialize">
	<cfset stCT = application.fapi.getContentObject(typename="alContentType", objectid=createUUID()) />
	<cfset stCT.contentType = url.contentType />
	<cfset stCT.datetimeBuiltTo = '1 Jan 1970' />
	<cfset stCT.configSignature = hash(serializeJSON(application.fc.lib.algolia.getIndexableTypes()[url.contentType])) />
	<cfset application.fapi.setData(stProperties=stCT) />

	<skin:bubble tags="success" message="#url.contentType# has been initialized. Now start uploading documents!" />
	<skin:location url="/index.cfm?contenttype=#url.contenttype#&objectid=#stCT.objectid#&type=alContentType&view=webtopPageModal&bodyView=webtopBodyUpload&mode=upload" />
</cfif>

<cfif url.mode eq "reindex">
	<cfset stObj.datetimeBuiltTo = '1 Jan 1970' />
	<cfset stObj.configSignature = hash(serializeJSON(application.fc.lib.algolia.getIndexableTypes()[stObj.contentType])) />
	<cfset application.fapi.setData(stProperties=stObj) />

	<skin:bubble tags="success" message="#stObj.contentType# has been reset for re-indexing. Now start uploading documents!" />
	<skin:location url="/index.cfm?contenttype=#stObj.contenttype#&objectid=#stObj.objectid#&type=alContentType&view=webtopPageModal&bodyView=webtopBodyUpload&mode=upload" />
</cfif>

<cfset typeLabel = application.fapi.getContentTypeMetadata(typename=stObj.contentType, md="displayname", default=stObj.contentType) />

<cfif structKeyExists(url, "run")>
	<cfset count = 0 />

	<cftry>
		<cfset atATime = 100 />
		<cfset stResult = application.fc.lib.algolia.bulkImportIntoIndex(stObject=stObj, maxRows=atATime, bDelete=false) />

		<cfif stResult.count>
			<cfset application.fapi.stream(type="json", content={
				"result"="#stResult.count# uploaded (built to: #timeFormat(stResult.builtToDate, 'hh:mm:sstt')# #dateFormat(stResult.builtToDate, 'd/mm/yyyy')#, query: #numberFormat(stResult.queryTime/1000, '0.00')#s, processing: #numberFormat(stResult.processingTime/1000, '0.00')#s, api: #numberFormat(stResult.apiTime/1000, '0.00')#s)",
				"more"=stResult.count eq atATime
			}) />
		</cfif>

		<cfcatch>
			<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
			<cfset application.fc.lib.error.logData(stError) />
			<cfif structKeyExists(stError, "detail") and isJSON(stError.detail)>
				<cfset stError.detail = deserializeJSON(stError.detail) />
			</cfif>
			<cfset application.fapi.stream(type="json", content={ "error"=stError }) />
		</cfcatch>
	</cftry>

	<cfset application.fapi.stream(type="json", content={
		"result"="No documents to upload",
		"more"=false
	}) />
</cfif>

<cfoutput>
	<h1>Upload #typeLabel# Documents</h1>
	<textarea id="upload-log" style="width:100%" rows=20></textarea>
	<ft:buttonPanel>
		<ft:button value="Start" onClick="startUpload(); return false;" />
		<ft:button value="Stop" onClick="stopUpload(); return false;" />
		<ft:button value="Clear" onClick="clearLog(); return false;" />
	</ft:buttonPanel>

	<script>
		var status = "stopped";

		document.getElementById("upload-log").value = "";
		function logUploadMessage(message, endline) {
			endline = endline || endline === undefined;
			document.getElementById("upload-log").value += message + (endline ? "\n" : "");
		}
		function startUpload() {
			if (status === "stopped") {
				logUploadMessage("Starting ...");
				status = "running";
				runUpload();
			}
		}
		function stopUpload() {
			if (status === "running") {
				logUploadMessage("Stopping ...");
				status = "stopping";
			}
		}
		function clearLog() {
			document.getElementById("upload-log").value = "";
		}

		function runUpload() {
			if (status === "stopping") {
				logUploadMessage("Stopped");
				status = "stopped";
				return;
			}

			logUploadMessage("Uploading ... ", false);

			$j.getJSON("#application.fapi.fixURL(addvalues='run=1')#", function(data, textStatus, jqXHR) {
				if (data.error) {
					logUploadMessage(data.error.message);
					logUploadMessage(JSON.stringify(data.error));
					status = "stopped";
				}
				else {
					logUploadMessage(data.result);

					if (data.more) {
						setTimeout(runUpload, 1);
					}
					else {
						logUploadMessage("Finished");
						status = "stopped";
					}
				}
			});
		}


		if (window.location.href.indexOf("autorun") > -1) {
			window.onload = startUpload();
		}
	</script>
</cfoutput>

<cfsetting enablecfoutputonly="false">