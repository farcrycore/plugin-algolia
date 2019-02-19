<cfsetting enablecfoutputonly="true">
<!--- @@displayName: Search results --->
<!--- @@viewStack: any --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfset baseFilter = application.fc.lib.algolia.getBaseFilter() />
<cfset restrictedKey = application.fc.lib.algolia.generateSecuredApiKey({
	'filters': baseFilter
}) />

<skin:htmlHead><cfoutput>
	<link rel="stylesheet" type="text/css" href="/algolia/instantsearch.min.css">
	<link rel="stylesheet" type="text/css" href="/algolia/instantsearch-theme-algolia.min.css">
	<script src="/algolia/instantsearch.js"></script>
</cfoutput></skin:htmlHead>

<cfoutput>
	<div id="query"></div>
	<div id="hits"></div>
	<script>
		const search = instantsearch({
			appId: #serializeJSON(application.fapi.getConfig("algolia", "applicationID"))#,
			apiKey: #serializeJSON(restrictedKey)#,
			indexName: #serializeJSON(application.fapi.getConfig("algolia", "indexName"))#,
			routing: true
		});

		search.addWidget(
			instantsearch.widgets.configure({
				attributesToRetrieve: ["typenamelabel","title","teaser","publishdate","publishdatelabel","url"],
				filters: '#baseFilter#'
			})
		);

			search.addWidget(
				instantsearch.widgets.searchBox({
					container: "##query",
					placeholder: "",
					poweredBy: false,
					reset: false,
					magnifier: false,
					loadingIndicator: true,
					wrapInput: false,
					autofocus: "auto",
					searchOnEnterKeyPressOnly: false
				})
			);

		search.addWidget(
			instantsearch.widgets.hits({
				container: '##hits',
				templates: {
					empty: 'No results',
					item: [
						'<div>',
						'	<h3>',
						'		<a href="{{url}}">{{title}}</a>',
						'	</h3>',
						'	<p>{{{teaser}}}</p>',
						'	<p>',
						'		<strong>{{typenamelabel}}</strong>',
						'		{{##publishDate}}',
						'			| <span>{{publishdatelabel}}</span>',
						'		{{/publishDate}}',
						'	</p>',
						'</div>'
					].join("\n")
				}
			})
		);

		search.start();
	</script>
</cfoutput>

<cfsetting enablecfoutputonly="false">