<cfsetting enablecfoutputonly="true" />
<!--- @@displayname: Algolia --->

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfset baseFilter = application.fc.lib.algolia.getBaseFilter() />
<cfset restrictedKey = application.fc.lib.algolia.generateSecuredApiKey({
	'filters': baseFilter,
	'restrictIndices': '#application.fapi.getConfig('algolia', 'indexName')#,#application.fapi.getConfig('algolia', 'indexName')#_publishdate_desc'
}) />

<skin:htmlHead><cfoutput>
	<link rel="stylesheet" type="text/css" href="/algolia/instantsearch.min.css">
	<link rel="stylesheet" type="text/css" href="/algolia/instantsearch-theme-algolia.min.css">
	<script src="/algolia/instantsearch.js"></script>
</cfoutput></skin:htmlHead>

<skin:loadJS id="fc-jquery" />
<skin:loadJS id="formatjson" />
<skin:htmlHead><cfoutput>
	<style>
		##message-log td, ##message-log th {
			padding: 5px;
		}
		##message-log .this-item td {
			background-color: ##dff0d8;
		}
		##message-log .related-item td {
			background-color: ##fcf8e3;
		}
		.formatjson .key {
			color:##a020f0;
		}
		.formatjson .number {
			color:##ff0000;
		}
		.formatjson .string {
			color:##000000;
		}
		.formatjson .boolean {
			color:##ffa500;
		}
		.formatjson .null {
			color:##0000ff;
		}
	</style>
</cfoutput></skin:htmlHead>

<cfset strOut = createObject("java","java.lang.StringBuffer").init() />
<cfset application.fc.lib.algolia.processObject(out=strOut, stObject=stObj) />
<cfset jsonOut = application.fapi.formatJSON(strOut.toString()) />
<ft:field label="Document"><cfoutput>
	<pre class="formatjson">#jsonOut#</pre>
	<p><a href='#application.fapi.getLink(type="alContentType", view="ajaxPush", urlParameters="pushtype=#stObj.typename#&pushID=#stObj.objectid#")#' onclick="$j(this).find('.info').remove().end().prepend('<i class=\'fa fa-spinner fa-spin info\'></i> '); $j.ajax({ url:this.href, dataType:'json', success:function(data){ $j(this).find('.fa').remove().end().append(' <span class=\'info\' style=\'text-decoration:none;cursor:default;'+(data.success ? 'color:green;' : 'color:red;')+'\'>'+data.message+'</span>'); }, context:this }); return false;">Push update to Algolia</a></p>
</cfoutput></ft:field>

<cfset stResult = application.fc.lib.cloudsearch.search(typename=stObj.typename,conditions=[{ "property"="objectid", "term"=stObj.objectid }]) />
<cfoutput>
	<h2>Label Search</h2>
	<div id="label_hits"></div>
	<script>
		const search = instantsearch({
			appId: #serializeJSON(application.fapi.getConfig("algolia", "applicationID"))#,
			apiKey: #serializeJSON(restrictedKey)#,
			indexName: #serializeJSON(application.fapi.getConfig("algolia", "indexName"))#,
			routing: false
		});

		search.addWidget(
			instantsearch.widgets.configure({
				attributesToRetrieve: ["objectID","typename","title","url"],
				filters: #serializeJSON(baseFilter)#,
				query: #serializeJSON(stObj.label)#
			})
		);

		search.addWidget(
			instantsearch.widgets.hits({
				container: '##label_hits',
				templates: {
					empty: 'No results',
					item: '<p>{{__hitIndex}}: {{objectID}} ({{typename}}) <a href="{{url}}">{{title}}</p>'
				}
			})
		);

		search.start();
	</script>
</cfoutput>
<!--- 
<cfset stResult = application.fc.lib.cloudsearch.search(rawQuery=stObj.label) />
<cfoutput><h2>Label Search</h2></cfoutput>
<ft:field label="Query"><cfoutput><pre>#stResult.rawQuery#</pre></cfoutput></ft:field>
<ft:field label="Filter"><cfoutput><pre>#stResult.rawFilter#</pre></cfoutput></ft:field>
<ft:field label="Results"><cfoutput>
	<table class="table table-striped">
		<thead>
			<tr>
				<th>Object ID</th>
				<th>Typename</th>
				<th>Label</th>
				<th></th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stResult.items">
				<cfset stObject = application.fapi.getContentObject(typename=stResult.items.typename,objectid=stResult.items.objectid) />

				<tr>
					<td>#stResult.items.objectid#</td>
					<td>#stResult.items.typename#</td>
					<td>#stObject.label#</td>
					<td><a title="#application.stCOAPI[stResult.items.typename].displayname# Overview" onclick="$fc.objectAdminAction('Media Overview', this.href, { onHidden : function(){} }); return false;" href="#application.url.webtop#/edittabOverview.cfm?typename=#stResult.items.typename#&method=edit&ref=iframe&objectid=#stResult.items.objectid#&dialogID=fcModal">Overview</a></td>
				</tr>
			</cfloop>
			<cfif stResult.items.recordcount eq 0>
				<tr>
					<td colspan="2">No items returned</td>
				</tr>
			</cfif>
		</tbody>
	</table>
</cfoutput></ft:field>
 --->
<cfsetting enablecfoutputonly="false" />