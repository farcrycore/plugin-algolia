component extends="farcry.core.packages.forms.forms" key="algolia" displayName="Algolia Search" fuAlias="search" hint="Algolia search service keys and index configuration." {

	property name="applicationID" type="string" required="false"
		ftSeq="1" ftWizardStep="" ftFieldset="Algolia Search" ftLabel="Application ID"
		ftHint="This is provided in the Algolia console";

	property name="indexName" type="string" required="false"
		ftSeq="2" ftWizardStep="" ftFieldset="Algolia Search" ftLabel="Index Name"
		ftHint="This is the unique index name for this application. Can contain letters, numbers, underscores, hyphens, and periods. Note: if you have multiple environments, you may want to incorporate the environment name in this value.";

	property name="adminAPIKey" type="string" required="false"
		ftSeq="3" ftWizardStep="" ftFieldset="Algolia Search" ftLabel="Admin API Key"
		ftHint="The API key to use for managing index settings and index data. If you wish to set up a custom ACL, this key needs [search, browse, addObject, deleteObject, settings, editSettings]";

	property name="queryAPIKey" type="string" required="false"
		ftSeq="4" ftWizardStep="" ftFieldset="Algolia Search" ftLabel="Query API Key"
		ftHint="The API key to use for searches. This is used on the front end in JavaScript and will be visible to users.";

	property name="indexConfig" type="longchar" required="false"
		ftSeq="5" ftWizardStep="" ftFieldset="Algolia Search" ftLabel="Index Config"
		ftHint="See the Algolia plugin README.md for details.";

	property name="bEnableEvent" type="boolean" required="false" default="true"
		ftSeq="6" ftWizardStep="" ftFieldset="Algolia Search" ftLabel="Enable Event"
		ftHint="Use to disable event in algolia plugin (Check to Enable)";

	public boolean function hasAmbiguousTimestamps(required string typename) {
		return queryExecute("
			SELECT		datetimeLastUpdated, count(*) as cnt
			FROM 		#arguments.typename#
			GROUP BY	datetimeLastUpdated
			HAVING		count(*) > 1
		", { }, { datasource=application.dsn_read }).recordcount gt 1;
	}

	public void function disambiguateTimestamps(required string typename) {
		switch (application.dbType) {
			case "mysql": case "h2":
				queryExecute("
					ALTER TABLE #arguments.typename#
					ADD `inc` INT NOT NULL AUTO_INCREMENT UNIQUE
				", { }, { datasource=application.dsn_read });
				queryExecute("
					UPDATE #arguments.typename#
					SET datetimeLastUpdated = DATE_ADD(date(datetimeLastUpdated), INTERVAL `inc` SECOND)
				", { }, { datasource=application.dsn_read });
				queryExecute("
					ALTER TABLE #arguments.typename#
					DROP COLUMN `inc`
				", { }, { datasource=application.dsn_read });
				break;

			case "mssql2005": case "mssql2012":
				queryExecute("
					ALTER TABLE #arguments.typename#
					ADD inc INT IDENTITY(1,1)
				", { }, { datasource=application.dsn_read });
				queryExecute("
					UPDATE #arguments.typename#
					SET datetimeLastUpdated = DATEADD(ss, inc, DATEADD(dd, DATEDIFF(dd, 0, datetimeLastUpdated), 0))
				", { }, { datasource=application.dsn_read });
				queryExecute("
					ALTER TABLE #arguments.typename#
					DROP COLUMN inc
				", { }, { datasource=application.dsn_read });
				break;
		}		
	}

}