<cfsetting enablecfoutputonly="true" requesttimeout="1000">

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />
<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<cfif structkeyexists(url,"deploy") and url.deploy eq 'alContentType'>
	<cfset application.fc.lib.db.deployType(typename=url.deploy, bDropTable=true, dsn=application.dsn) />
	<skin:bubble tags="success" message="alContentType has been deployed" />
	<skin:location url="#application.fapi.fixURL(removevalues='deploy')#" />
</cfif>

<cfif structKeyExists(url,"disamb")>
	<cfset disambiguateTimestamps(url.disamb) />
	<skin:bubble tags="success" message="#url.disamb# has been disambiguated" />
	<skin:location url="#application.fapi.fixURL(removevalues='disamb')#" />
</cfif>

<ft:processform action="Apply Changes">
	<cfset stDiffs = application.fc.lib.algolia.diffAlgoliaSettings() />
	<cfset application.fc.lib.algolia.applyAlgoliaSettings(argumentCollection=stDiffs) />
	<skin:bubble tags="success" message="#structKeyList(stDiffs, ', ')# have been updated" />
	<skin:location url="#application.fapi.fixURL()#" />
</ft:processform>

<ft:processform action="Reset All">
	<cfset qTypes = application.fapi.getContentObjects(typename='alContentType', lProperties="objectid,datetimeBuiltTo") />
	<cfloop query="qTypes">
		<cfif application.fapi.showFarCryDate(qTypes.datetimeBuiltTo)>
			<cfset application.fapi.setData(stProperties={ objectid=qTypes.objectid, typename="alContentType", datetimeBuiltTo="1 Jan 1970" }) />
		</cfif>
	</cfloop>
	<skin:bubble tags="success" message="#qTypes.recordcount# have been reset" />
	<skin:location url="#application.fapi.fixURL()#" />
</ft:processform>

<cfset configValidation = application.fc.lib.algolia.validateConfig() />
<cfset alContentTypeDeployed = application.fc.lib.db.isDeployed(typename="alContentType", dsn=application.dsn) />
<cfoutput>
	<h1>Algolia Status</h1>
	<p>Note that the Algolia plugin was written to be intialized once. In order to update settings you will need to restart FarCry.</p>

	<table class="table table-striped">
		<tbody>
			<tr>
				<th>API Configured:</th>
				<td>#yesNoFormat(application.fc.lib.algolia.isConfigured())#</td>
			</tr>
			<tr>
				<th>alContentType Deployed:</th>
				<td>
					#yesNoFormat(alContentTypeDeployed)#
					<cfif not alContentTypeDeployed>
						(<a href="#application.fapi.fixURL(addvalues='deploy=alContentType')#">deploy now</a>)
					</cfif>
				</td>
			<tr>
				<th>Indexing config:</th>
				<td>
					<cfif configValidation.valid>
						Valid <cfif arrayLen(configValidation.details)>(#configValidation.details[1]#)</cfif>
					<cfelse>
						Invalid:
						<ul>
							<cfloop array="#configValidation.details#" index="i">
								<li>#i#</li>
							</cfloop>
						</ul>
					</cfif>
				</td>
			</tr>
		</tbody>
	</table>
</cfoutput>

<cfif configValidation.valid>
	<cfset expandedConfig = application.fc.lib.algolia.getExpandedConfig() />

	<cfset stDiffs = application.fc.lib.algolia.diffAlgoliaSettings() />
	<ft:form>
		<cfoutput>
			<h1>Configuration - Index</h1>
			<table class="table table-striped">
				<tbody>
					<cfloop collection="#expandedConfig#" item="indexName">
						<tr>
							<th><code>#indexName#</code> <cfif expandedConfig[indexName].replica> (replica)</cfif></th>
							<th><code>attributesForFaceting</code></th>
							<td>
								#arrayToList(expandedConfig[indexName].settings.attributesForFaceting, ", ")#
								<cfif structKeyExists(stDiffs, "#indexName#.attributesForFaceting")>
									<strong style="color:red;">Changed</strong>
								</cfif>
							</td>
						</tr>
						
						<tr>
							<th></th>
							<th><code>searchableAttributes</code></th>
							<td>
								#arrayToList(expandedConfig[indexName].settings.searchableAttributes, ", ")#
								<cfif structKeyExists(stDiffs, "#indexName#.searchableAttributes")>
									<strong style="color:red;">Changed</strong>
								</cfif>
							</td>
						</tr>
						
						<tr>
							<th></th>
							<th><code>ranking</code></th>
							<td>
								#arrayToList(expandedConfig[indexName].settings.ranking, ", ")#
								<cfif structKeyExists(stDiffs, "#indexName#.ranking")>
									<strong style="color:red;">Changed</strong>
								</cfif>
							</td>
						</tr>
						<tr>
							<th></th>
							<th><code>replicas</code></th>
							<td>
								#arrayToList(expandedConfig[indexName].settings.replicas, ", ")#
								<cfif structKeyExists(stDiffs, "#indexName#.replicas")>
									<strong style="color:red;">Changed</strong>
								</cfif>
							</td>
						</tr>

						<tr>
							<th></th>
							<th><code>distinct</code></th>
							<td>
								#expandedConfig[indexName].settings.distinct#
								<cfif structKeyExists(stDiffs, "#indexName#.distinct")>
									<strong style="color:red;">Changed</strong>
								</cfif>
							</td>
						</tr>
						<tr>
							<th></th>
							<th><code>attributeForDistinct</code></th>
							<td>
								#expandedConfig[indexName].settings.attributeForDistinct#
								<cfif structKeyExists(stDiffs, "#indexName#.attributeForDistinct")>
									<strong style="color:red;">Changed</strong>
								</cfif>
							</td>
						</tr>
					</cfloop>
				</tbody>
			</table>
		</cfoutput>
		<cfif not structIsEmpty(stDiffs)>
			<ft:buttonPanel>
				<ft:button value="Apply Changes" />
			</ft:buttonPanel>
		</cfif>
	</ft:form>

	<cfset indexableTypes = application.fc.lib.algolia.getIndexableTypes() />
	<cfoutput>
		<h2>Configuration - Data to index</h2>
		<table class="table table-striped">
			<tbody>
				<cfloop collection="#indexableTypes#" item="typename">
					<cfset bAmbiguousTimestamps = hasAmbiguousTimestamps(typename) />

					<tr>
						<td>#application.fapi.getContentTypeMetadata(typename, "displayName", typename)#</td>
						<td>
							<cfloop collection="#indexableTypes[typename]#" item="indexName">
								<strong>#indexName#</strong>: #structKeyList(indexableTypes[typename][indexName], ", ")#<br>
							</cfloop>
						</td>

						<cfif alContentTypeDeployed>
							<cfset qBuildInfo = application.fapi.getContentObjects(typename="alContentType", lProperties="objectid,datetimeBuiltTo,configSignature", contentType_eq=typename) />

							<cfif qBuildInfo.recordcount>
								<td width="15%">#timeFormat(qBuildInfo.datetimeBuiltTo, "HH:mm")#, #dateFormat(qBuildInfo.datetimeBuiltTo, "d mmm yyyy")#</td>
								<td width="15%">
									<cfif bAmbiguousTimestamps>
										<a title="This content type has ambiguous timestamps." href="#application.fapi.fixURL(addvalues='disamb=#typename#')#">Disambiguate timestamps</a><br>
									</cfif>

									<cfif hash(serializeJSON(indexableTypes[typename])) eq qBuildInfo.configSignature>
										Schema is up to date<br>
										<a title="Start uploading data" href="javascript:$fc.objectAdminAction('Upload Data', '/index.cfm?objectid=#qBuildInfo.objectid#&type=alContentType&view=webtopPageModal&bodyView=webtopBodyUpload&mode=upload');">Upload</a><br>
										<a title="Re-upload all data" href="javascript:$fc.objectAdminAction('Upload Data', '/index.cfm?objectid=#qBuildInfo.objectid#&type=alContentType&view=webtopPageModal&bodyView=webtopBodyUpload&mode=reindex');">Re-upload</a><br>
									<cfelse>
										<a title="Schema has changed, you should re-index this type" href="javascript:$fc.objectAdminAction('Upload Data', '/index.cfm?objectid=#qBuildInfo.objectid#&type=alContentType&view=webtopPageModal&bodyView=webtopBodyUpload&mode=reindex');">Re-upload</a><br>
									</cfif>
								</td>
							<cfelse>
								<td width="15%">N/A</td>
								<td width="15%">
									<cfif bAmbiguousTimestamps>
										<a title="This content type has ambiguous timestamps." href="#application.fapi.fixURL(addvalues='disamb=#typename#')#">Disambiguate timestamps</a><br>
									</cfif>
									<a title="This type has never been indexed" href="javascript:$fc.objectAdminAction('Upload Data', '/index.cfm?contentType=#typename#&type=alContentType&view=webtopPageModal&bodyView=webtopBodyUpload&mode=initialize');">Upload</a><br>
								</td>
							</cfif>
						</cfif>
					</tr>
				</cfloop>
			</tbody>
		</table>
	</cfoutput>
	<ft:form>
		<ft:buttonPanel>
			<ft:button value="Reset All" />
		</ft:buttonPanel>
	</ft:form>
</cfif>

<cfif application.fc.lib.algolia.isConfigured()>
	<cfoutput><h1>Application Configuration</h1></cfoutput>
	<cfdump var="#application.fc.lib.algolia.getExpandedConfig()#" />

	<cfoutput><h1>Algolia Index Settings</h1></cfoutput>
	<cfdump var="#application.fc.lib.algolia.getSettings()#">
	
	<cfdump var="#application.fc.lib.algolia.getSettings(indexName='ajmdev_yaffa_dsp_company')#" label="ajmdev_yaffa_dsp_company">
</cfif>

<cfsetting enablecfoutputonly="false">