component {

	public boolean function isConfigured(
		string applicationID = application.fapi.getConfig("algolia", "applicationID"),
		string indexName = application.fapi.getConfig("algolia", "indexName"),
		string adminAPIKey = application.fapi.getConfig("algolia", "adminAPIKey"),
		string queryAPIKey = application.fapi.getConfig("algolia", "queryAPIKey"),
		string indexConfig = application.fapi.getConfig("algolia", "indexConfig")
	) {
		if (not structKeyExists(this, "searchEnabled")) {
			var stValidation = validateConfig(arguments.indexConfig);

			this.searchEnabled = arguments.applicationID neq ""
				AND arguments.indexName neq ""
				AND arguments.adminAPIKey neq ""
				AND arguments.queryAPIKey neq ""
				AND stValidation.valid;

			if (stValidation.valid) {
				this.indexConfig = stValidation.value;
			}
		}

		return this.searchEnabled;
	}

	public struct function validateConfig(string indexConfig = application.fapi.getConfig("algolia", "indexConfig")) {
		if (arguments.indexConfig eq "") {
			return { valid: false, details: ["No configuration"] };
		}

		if (not isJSON(arguments.indexConfig)) {
			return { valid: false, details: ["Not valid JSON"] };
		}

		var stResult = { valid: true, details: [], value: {} };
		var stIndexConfig = deserializeJSON(arguments.indexConfig);
		var stSub = {};

		// validate settings
		if (structKeyExists(stIndexConfig, "settings")) {
			stSub = validateSettings(stIndexConfig.settings);
			stResult.valid = stResult.valid AND stSub.valid;
			arrayAppend(stResult.details, stSub.details, true);
			stResult.value["settings"] = stSub.value;
		}
		else {
			stResult.value["settings"] = validateSettings({}).value;
		}

		// validate config.types
		if (structKeyExists(stIndexConfig, "types")) {
			stSub = validateConfigTypes(stIndexConfig.types);
			stResult.valid = stResult.valid AND stSub.valid;
			arrayAppend(stResult.details, stSub.details, true);
			stResult.value["types"] = stSub.value;
		}

		return stResult;
	}

	private struct function validateSettings(required any settings) {
		var stResult = { valid: true, details: [], value: {} };
		var stSub = {};
		var i = 0;
		var replicaName = "";
		var orderValue = "";

		// maxFieldSize
		if (structKeyExists(arguments.settings, "maxFieldSize")) {
			stSub = validateSettingsMaxFieldSize(arguments.settings.maxFieldSize);
		}
		else {
			stSub = validateSettingsMaxFieldSize();
		}
		stResult.valid = stResult.valid AND stSub.valid;
		arrayAppend(stResult.details, stSub.details, true);
		stResult.value["maxFieldSize"] = stSub.value;

		// attributesForFaceting
		if (structKeyExists(arguments.settings, "attributesForFaceting")) {
			stSub = validateSettingsAttributesForFaceting(arguments.settings.attributesForFaceting);
		}
		else {
			stSub = validateSettingsAttributesForFaceting();
		}
		stResult.valid = stResult.valid AND stSub.valid;
		arrayAppend(stResult.details, stSub.details, true);
		stResult.value["attributesForFaceting"] = stSub.value;

		// ordering
		if (structKeyExists(arguments.settings, "ordering")) {
			stSub = validateSettingsOrdering(arguments.settings.ordering);
		}
		else {
			stSub = validateSettingsOrdering();
		}
		stResult.valid = stResult.valid AND stSub.valid;
		arrayAppend(stResult.details, stSub.details, true);
		stResult.value["ordering"] = stSub.value;
		structAppend(stResult.value, expandOrdering(stResult.value["ordering"], arguments.settings), true);

		return stResult;
	}

	private struct function validateSettingsMaxFieldSize(any maxFieldSize=5000) {
		var stResult = { valid: true, details: [], value: 0 };

		if (not isNumeric(arguments.maxFieldSize)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "settings.maxFieldSize is not a number");
			return stResult;
		}

		stResult.value = arguments.maxFieldSize;

		return stResult;
	}

	private struct function validateSettingsAttributesForFaceting(any attributesForFaceting=["filterOnly(status)","filterOnly(publishdate)","filterOnly(expirydate)"]) {
		var stResult = { valid: true, details: [], value: [] };
		var i = 0;

		if (not isArray(arguments.attributesForFaceting)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "settings.attributesForFaceting is not an array");
			return stResult;
		}

		stResult.value = arguments.attributesForFaceting;
		for (i=1; i<=arrayLen(arguments.attributesForFaceting); i++) {
			if (not isSimpleValue(arguments.attributesForFaceting[i])) {
				stResult.valid = false;
				arrayAppend(stResult.details, "settings.attributesForFaceting[#i#] is not a string");
				structDelete(stResult.value, "attributesForFaceting");
				break;
			}
		}

		if (not arrayFind(stResult.value, "filterOnly(status)")) {
			arrayAppend(stResult.value, "filterOnly(status)")
		}

		if (not arrayFind(stResult.value, "filterOnly(publishdate)")) {
			arrayAppend(stResult.value, "filterOnly(publishdate)")
		}

		if (not arrayFind(stResult.value, "filterOnly(expirydate)")) {
			arrayAppend(stResult.value, "filterOnly(expirydate)")
		}

		return stResult;
	}

	private struct function validateSettingsOrdering(any ordering=[]) {
		var stResult = { valid: true, details: [], value: [] };

		if (not isArray(arguments.ordering)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "settings.ordering is not an array");
			return stResult;
		}

		stResult.value = arguments.ordering;
		for (i=1; i<=arrayLen(arguments.ordering); i++) {
			if (not reFind("^[\w_]+ (asc|desc)(,[\w_]+ (asc|desc))*$", arguments.ordering[i])) {
				stResult.valid = false;
				arrayAppend(stResult.details, "settings.ordering[#i#] is not a valid order string");
				break;
			}
		}

		return stResult;
	}

	private struct function expandOrdering(required array ordering, required any settings) {
		var indexName = application.fapi.getConfig("algolia", "indexName");
		var i = 0;
		var replicaName = "";
		var orderingValue = "";
		var stResult = {
			"replicas": [],
			"replica_settings": {}
		};

		for (i=1; i<=arrayLen(arguments.ordering); i++) {
			replicaName = indexName & "_" & lcase(reReplace(arguments.ordering[i], "[^\w_]+", "_", "ALL"));
			arrayAppend(stResult["replicas"], replicaName);

			stResult["replica_settings"][replicaName] = {
				"ranking": [],
				"attributesForFaceting": arguments.settings.attributesForFaceting
			};
			for (orderValue in listToArray(arguments.ordering[i])) {
				switch (listLast(orderValue, " ")) {
					case "asc": arrayAppend(stResult["replica_settings"][replicaName].ranking, "asc(#lcase(listFirst(orderValue, ' '))#)"); break;
					case "desc": arrayAppend(stResult["replica_settings"][replicaName].ranking, "desc(#lcase(listFirst(orderValue, ' '))#)"); break;
				}
			}
			arrayAppend(stResult["replica_settings"][replicaName].ranking, listToArray("typo,geo,words,filters,proximity,attribute,exact,custom"), true);
		}

		return stResult;
	}

	private struct function validateConfigTypes(required any types) {
		if (not isStruct(arguments.types)) {
			return { valid: false, details: ["config.types is not a struct"], value: {} };
		}

		var stTypeValidation = {};
		var typename = "";
		var stResult = { valid: true, details: [], value: {} };

		for (typename in arguments.types) {
			stTypeValidation = validateConfigType(typename, arguments.types[typename]);
			stResult.valid = stResult.valid AND stTypeValidation.valid;
			arrayAppend(stResult.details, stTypeValidation.details, true);
			stResult.value[typename] = stTypeValidation.value;
		}

		return stResult;
	}

	private struct function validateConfigType(required string typename, required any typeConfig) {
		var stResult = { valid: true, details: [], value: {} };

		// typename must be valid
		if (not structKeyExists(application.stCOAPI, arguments.typename)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "`#arguments.typename#` in config.types is not a known content type");
		}

		// config must be valid
		if (not isStruct(arguments.typeConfig)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "value of config.types.#arguments.typename# is not a struct");
			return stResult;
		}

		var property = "";
		var oType = application.fapi.getContentType(arguments.typename);

		var stPropertyValidation = {};
		for (property in arguments.typeConfig) {
			stPropertyValidation = validateConfigProperty(arguments.typename, property, arguments.typeConfig[property]);
			stResult.valid = stResult.valid && stPropertyValidation.valid;
			arrayAppend(stResult.details, stPropertyValidation.details, true);
			stResult.value[property eq "objectid" ? "objectID" : lcase(property)] = stPropertyValidation.value;
		}

		// if no properties were defined, add all of the valid ones
		if (structIsEmpty(arguments.typeConfig)) {
			for (property in application.stCOAPI[typename].stProps) {
				stResult.value[property] = {
					"from": property
				};

				if (structKeyExists(oType, "process#property#")) {
					stResult.value[property]["processFn"] = "process#property#";
				}
				else if (structKeyExists(this, "process#application.fapi.getPropertyMetadata(arguments.typename, property, "ftType", "none")#")) {
					stResult.value[property]["type"] = application.fapi.getPropertyMetadata(arguments.typename, property, "ftType", "none");
				}
				else  if (structKeyExists(this, "process#application.fapi.getPropertyMetadata(arguments.typename, property, "type", "none")#")) {
					stResult.value[property]["type"] = application.fapi.getPropertyMetadata(arguments.typename, property, "type", "none");
				}
				else {
					structDelete(stResult.value, property);
				}
			}
		}

		// add missing properties
		if (not structKeyExists(stResult.value, "objectid")) {
			stResult.value["objectID"] = { "from":"objectID", "type": "string" };
		}
		if (not structKeyExists(stResult.value, "typename")) {
			stResult.value["typename"] = { "from":"typename", "type": "string" };
		}
		if (not structKeyExists(stResult.value, "typenameLabel")) {
			stResult.value["typenamelabel"] = { "type": "typenameLabel" };
		}
		if (not structKeyExists(stResult.value, "status")) {
			stResult.value["status"] = { "type": "status" };
		}
		if (not structKeyExists(stResult.value, "publishDate")) {
			stResult.value["publishdate"] = { "from":"datetimeCreated", "type": "datetime" };
		}
		if (not structKeyExists(stResult.value, "publishDateLabel")) {
			if (structKeyExists(application.stCOAPI[typename].stProps, "publishDate")) {
				stResult.value["publishdatelabel"] = { "from":"publishDate", "type": "dateasstring" };
			}
			else {
				stResult.value["publishdatelabel"] = { "from":"datetimeCreated", "type": "dateasstring" };
			}
		}
		if (not structKeyExists(stResult.value, "expiryDate")) {
			stResult.value["expirydate"] = { "value":"-1" };
		}
		if (not structKeyExists(stResult.value, "url")) {
			stResult.value["url"] = { "type": "friendlyurl" };
		}

		return stResult;
	}

	public struct function validateConfigProperty(required string typename, required string property, required struct propertyConfig) {
		var stResult = { valid: true, details: [], value: duplicate(arguments.propertyConfig) };
		var oType = {};
		var i = 0;

		// config must be valid
		if (not isStruct(arguments.propertyConfig)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "value of config.types.#arguments.typename#.#arguments.property# is not a struct");
			return stResult;
		}

		// validate specified values
		if (structKeyExists(stResult.value, "from") and not structKeyExists(application.stCOAPI[arguments.typename].stProps, stResult.value.from)) {
			stResult.valid = false;
			arrayAppend(stResult.details, "config.types.#arguments.typename#.#arguments.property#.from must be a valid variable name");
		}
		if (structKeyExists(stResult.value, "type") and not structKeyExists(this, "process#stResult.value.type#")) {
			stResult.valid = false;
			arrayAppend(stResult.details, "unknown type for config.types.#arguments.typename#.#arguments.property#");
			return stResult;
		}
		if (structKeyExists(stResult.value, "processFn")) {
			oType = application.fapi.getContentType(arguments.typename);

			if (not structKeyExists(oType, stResult.value.processFn)) {
				stResult.valid = false;
				arrayAppend(stResult.details, "config.types.#arguments.typename#.#arguments.property#.processFn does not match a function in #arguments.typename#.cfc");
				return stResult;
			}
		}

		// add missing values
		if (not structKeyExists(stResult.value, "from")) {
			if (structKeyExists(application.stCOAPI[arguments.typename].stProps, arguments.property)) {
				stResult.value["from"] = arguments.property;
			}
		}
		if (not structKeyExists(stResult.value, "type") and not structKeyExists(stResult.value, "processFn") and not structKeyExists(stResult.value, "value")) {
			oType = application.fapi.getContentType(arguments.typename);

			if (structKeyExists(oType, "process#arguments.property#")) {
				stResult.value["processFn"] = "process#arguments.property#";
			}
			else if (structKeyExists(stResult.value, "from") and structKeyExists(this, "process#application.fapi.getPropertyMetadata(arguments.typename, stResult.value.from, "ftType", "none")#")) {
				stResult.value["type"] = application.fapi.getPropertyMetadata(arguments.typename, stResult.value.from, "ftType", "none");
			}
			else  if (structKeyExists(stResult.value, "from") and structKeyExists(this, "process#application.fapi.getPropertyMetadata(arguments.typename, stResult.value.from, "type", "none")#")) {
				stResult.value["type"] = application.fapi.getPropertyMetadata(arguments.typename, stResult.value.from, "type", "none");
			}
			else if (listFindNoCase("typename", arguments.property)) {
				stResult.value["type"] = "string";
			}
			else {
				stResult.valid = false;
				arrayAppend(stResult.details, "config.types.#arguments.typename#.#arguments.property# does not have a known type or a processing function");
			}
		}

		return stResult;
	}

	public struct function diffAlgoliaSettings() {
		var indexName = application.fapi.getConfig("algolia", "indexName");
		var indexConfig = getExpandedConfig();
		var algoliaSettings = getSettings();
		var stResult = {};
		var i = 0;

		if (not structKeyExists(algoliaSettings, "attributesForFaceting") OR serializeJSON(indexConfig.settings.attributesForFaceting) neq serializeJSON(algoliaSettings.attributesForFaceting)) {
			stResult["attributesForFaceting"] = true;
		}

		if (arrayLen(indexConfig.settings.replicas) and (not structKeyExists(algoliaSettings, "replicas") OR serializeJSON(indexConfig.settings.replicas) neq serializeJSON(algoliaSettings.replicas))) {
			stResult["ordering"] = true;
		}

		return stResult;
	}

	public void function applyAlgoliaSettings(boolean attributesForFaceting=false, boolean ordering=false) {
		var stSettings = {};
		var stReplicaSettings = {};
		var indexConfig = getExpandedConfig();
		var replicaConfig = {};
		var replicaName = "";

		if (arguments.attributesForFaceting) {
			stSettings["attributesForFaceting"] = indexConfig.settings.attributesForFaceting;
		}

		if (arguments.ordering) {
			stSettings["replicas"] = indexConfig.settings.replicas;
		}

		if (not structIsEmpty(stSettings)) {
			setSettings(data=serializeJSON(stSettings), forwardToReplicas=true);
		}

		if (arguments.ordering) {
			for (replicaName in indexConfig.settings.replicas) {
				stReplicaSettings = getSettings(replicaName);
				replicaConfig = {};

				if (structIsEmpty(stReplicaSettings) or serializeJSON(stReplicaSettings.ranking) neq serializeJSON(indexConfig.settings.replica_settings[replicaName].ranking)) {
					replicaConfig["ranking"] = indexConfig.settings.replica_settings[replicaName].ranking;
				}

				if (not structIsEmpty(replicaConfig)) {
					setSettings(indexName=replicaName, data=serializeJSON(replicaConfig));
				}
			}
		}
	}

	public struct function getExpandedConfig() {
		if (not structKeyExists(this, "indexConfig") and isConfigured()) {
			// isConfigured sets indexConfig
		}

		return this.indexConfig;
	}

	public boolean function isIndexable(required struct stObject) {
		if (not isConfigured()) {
			return false;
		}

		if (not application.fc.lib.db.isDeployed(typename="alContentType", dsn=application.dsn)) {
			return false;
		}

		var qContentType = application.fapi.getContentObjects(typename="alContentType", contentType_eq=arguments.stObject.typename);
		if (qContentType.recordcount eq 0) {
			return false;
		}

		var indexConfig = getExpandedConfig();
		return structKeyExists(indexConfig.types, arguments.stObject.typename);
	}

	public struct function getTypeIndexFields(required string typename) {
		var indexConfig = getExpandedConfig();

		return indexConfig.types[arguments.typename];
	}

	public struct function getConfiguredSettings() {
		var indexConfig = getExpandedConfig();

		return indexConfig.settings;
	}

	public query function getRecordsToUpdate(required string typename, required string builtToDate, maxRows=-1, boolean bDelete=false) {
		var sql = "";
		var vars = {};

		if (application.fapi.showFarcryDate(arguments.builtToDate)) {
			sql = "
				select 		objectid, datetimeLastUpdated, '#arguments.typename#' as typename, 'updated' as operation
				from 		#application.dbowner##arguments.typename#
				where 		datetimeLastUpdated > :builtToDate
			";
			vars["builtToDate"] = {
				cfsqltype = "cf_sql_timestamp",
				value = arguments.builtToDate
			};

			if (arguments.bDelete) {
				sql &= "
					UNION

					select 		archiveID as objectid, datetimeCreated as datetimeLastUpdated, '#arguments.typename#' as typename, 'deleted' as operation
					from 		#application.dbowner#dmArchive
					where 		objectTypename = :typename
								and bDeleted = 1
								and datetimeLastUpdated > :builtToDate
				";
				vars["typename"] = arguments.typename;
			}

			sql &= " order by 	datetimeLastUpdated asc";
		}
		else {
			sql = "
				select 		objectid, datetimeLastUpdated, '#arguments.typename#' as typename, 'updated' as operation
				from 		#application.dbowner##arguments.typename#
			";

			if (arguments.bDelete) {
				sql &= "
					UNION

					select 		archiveID as objectid, datetimeCreated as datetimeLastUpdated, '#arguments.typename#' as typename, 'deleted' as operation
					from 		#application.dbowner#dmArchive
					where 		objectTypename = :typename
								and bDeleted = 1
				";
				vars["typename"] = arguments.typename;
			}

			sql &= "order by 	datetimeLastUpdated asc";
		}

		return queryExecute(sql, vars, { datasource=application.dsn_read, maxrows=arguments.maxrows });
	}

	public struct function importIntoIndex(uuid objectID, string typename, struct stObject, required string operation) {
		var oContent = "";
		var strOut = createObject("java","java.lang.StringBuffer").init();
		var builtToDate = "";
		var stResult = {};

		if (not structKeyExists(arguments,"stObject")) {
			arguments.stObject = application.fapi.getContentData(typename=arguments.typename,objectid=arguments.objectid);
		}

		oContent = application.fapi.getContentType(typename=arguments.stObject.typename);

		strOut.append('{ "requests": [ ');

		if (arguments.operation eq "updated" and (not structKeyExists(oContent, "isIndexable") or oContent.isIndexable(stObject=stObject))) {
			strOut.append('{ "action": "addObject", "body": ');
			processObject(strOut, arguments.stObject);
			strOut.append(' }');
			builtToDate = arguments.stObject.datetimeLastUpdated;
		}
		else if (arguments.operation eq "deleted") {
			strOut.append('{ "action": "deleteObject", "body": ');
			strOut.append('{ "objectID": "');
			strOut.append(arguments.stObject.objectid);
			strOut.append('" } }');
			builtToDate = now();
		}

		strOut.append(' ] }');

		stResult = customBatch(strOut.toString());
		queryExecute("
			update 	#application.dbowner#alContentType
			set 	datetimeBuiltTo=:builtToDate
			where 	contentType=:contentType
		", { builtToDate={ cfsqltype="cf_sql_timestamp", value=builtToDate }, contentType=arguments.stObject.typename }, { datasource=application.dsn });
		writeLog(file="algolia", text="Updated 1 #arguments.stObject.typename# record/s");

		stResult["typename"] = arguments.stObject.typename;
		stResult["count"] = 1;
		stResult["builtToDate"] = builtToDate;

		return stResult;
	}

	public struct function bulkImportIntoIndex(uuid objectid, struct stObject, numeric maxRows, numeric requestSize=5000000, boolean bDelete=false) {
		var qContent = "";
		var oContent = "";
		var stContent = "";
		var stContent = {};
		var strOut = createObject("java","java.lang.StringBuffer").init();
		var builtToDate = "";
		var stResult = {};
		var count = 0;
		var row = {};
		var indexName = application.fapi.getConfig("algolia", "indexName");
		var start = 0;
		var queryTime = 0;
		var processingTime = 0;
		var apiTime = 0;

		if (not structKeyExists(arguments,"stObject")) {
			arguments.stObject = application.fapi.getData(typename='alContentType', objectid=arguments.objectid);
		}

		oContent = application.fapi.getContentType(typename=arguments.stObject.contentType);

		start = getTickCount();
		qContent = getRecordsToUpdate(typename=arguments.stObject.contentType, builtToDate=arguments.stObject.datetimeBuiltTo, maxRows=arguments.maxRows, bDelete=arguments.bDelete);
		queryTime = getTickCount() - start;

		builtToDate = arguments.stObject.datetimeBuiltTo;

		strOut.append('{ "requests": [ ');

		start = getTickCount();
		for (row in qContent) {
			if (qContent.operation eq "updated" and (not structKeyExists(oContent, "isIndexable") or oContent.isIndexable(stObject=stObject))) {
				stContent = oContent.getData(objectid=qContent.objectid);

				strOut.append('{ "action": "addObject", "body": ');
				processObject(strOut, stContent);
				strOut.append(' }');
			}
			else if (qContent.operation eq "deleted") {
				strOut.append('{ "action": "deleteObject", "body": ');
				strOut.append('{ "objectID": "');
				strOut.append(qContent.objectid);
				strOut.append('" } }');
			}

			if (strOut.length() * ((qContent.currentrow+1) / qContent.currentrow) gt arguments.requestSize or qContent.currentrow eq qContent.recordcount) {
				builtToDate = qContent.datetimeLastUpdated;
				count = qContent.currentrow;
				break;
			}
			else {
				strOut.append(', ');
			}
		}
		processingTime += getTickCount() - start;

		strOut.append(' ] }');

		if (count) {
			start = getTickCount();
			stResult = customBatch(strOut.toString());
			apiTime = getTickCount() - start;

			arguments.stObject.datetimeBuiltTo = builtToDate;
			application.fapi.setData(stProperties=arguments.stObject);
			writeLog(file="cloudsearch", text="Updated #count# #arguments.stObject.contentType# record/s");
		}

		stResult["typename"] = arguments.stObject.contentType;
		stResult["count"] = count;
		stResult["builtToDate"] = builtToDate;
		stResult["queryTime"] = queryTime;
		stResult["processingTime"] = processingTime;
		stResult["apiTime"] = apiTime;

		return stResult;
	}

	public void function processObject(required any out, struct stObject) {
		var oType = application.fapi.getContentType(arguments.stObject.typename);
		var stFields = getTypeIndexFields(arguments.stObject.typename);
		var stSettings = getConfiguredSettings();

		arguments.out.append('{ ');

		var property = "";
		var first = true;
		for (property in stFields) {
			if (not first) {
				arguments.out.append(', ');
			}
			first = false;

			arguments.out.append('"#property#": ');

			// If there is a function in the type for this property, use that instead of the default
			if (structKeyExists(stFields[property], "value")) {
				out.append(stFields[property].value);
			}
			else if (structKeyExists(stFields[property], "processFn")) {
				cfinvoke(component=oType, method=stFields[property].processFn) {
					cfinvokeargument(name="out", value=arguments.out);
					cfinvokeargument(name="stObject", value=arguments.stObject);
					cfinvokeargument(name="propertyConfig", value=stFields[property]);
					cfinvokeargument(name="settings", value=stSettings);
				}
			}
			else {
				cfinvoke(component=this, method="process#stFields[property].type#") {
					cfinvokeargument(name="out", value=arguments.out);
					cfinvokeargument(name="stObject", value=arguments.stObject);
					cfinvokeargument(name="propertyConfig", value=stFields[property]);
					cfinvokeargument(name="settings", value=stSettings);
				}
			}
		}

		arguments.out.append(' }');
	}


	// These are the default processing functions for the various property types. The import will first look for
	// process[ftType], then for process[type]
	// Properties that don't have their type here, or which don't have a custom serialization function
	// will throw an error
	// All of these functions should accept a Java string buffer "out" and write the value to that. This
	// ensures that weird CFML JSON serialization bugs won't cause issues down the line.
	public void function processDateTime(required any out, required struct stObject, required struct propertyConfig) {
		if (isDate(arguments.stObject[arguments.propertyConfig.from])) {
			arguments.out.append(numberFormat(round(arguments.stObject[arguments.propertyConfig.from].getTime() / 1000), "0"));
		}
		else {
			arguments.out.append("-1")
		}
	}

	public void function processDateAsString(required any out, required struct stObject, required struct propertyConfig) {
		if (isDate(arguments.stObject[arguments.propertyConfig.from])) {
			arguments.out.append('"');
			arguments.out.append(dateFormat(arguments.stObject[arguments.propertyConfig.from], "d mmmm yyyy"));
			arguments.out.append('"');
		}
		else {
			arguments.out.append('""');
		}
	}

	public void function processNumeric(required any out, required struct stObject, required struct propertyConfig) {
		var value = arguments.stObject[arguments.propertyConfig.from];

		if (len(value)) {
			arguments.out.append(value);
		}
		else if (len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "ftDefault", ""))) {
			arguments.out.append(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "ftDefault"));
		}
		else if (len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "default", ""))) {
			arguments.out.append(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "default"));
		}
	}

	public void function processInteger(required any out, required struct stObject, required struct propertyConfig) {
		var value = arguments.stObject[arguments.propertyConfig.from];

		if (len(value)) {
			arguments.out.append(numberFormat(value, "0"));
		}
		else if (len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "ftDefault", ""))) {
			arguments.out.append(numberFormat(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "ftDefault"), "0"));
		}
		else if (len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "default", ""))) {
			arguments.out.append(numberFormat(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "default"), "0"));
		}
	}

	public void function processString(required any out, required struct stObject, required struct propertyConfig, required struct settings) {
		if (application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.propertyConfig.from, "ftRichtextConfig", "") neq "") {
			processRichText(argumentCollection=arguments);
		}
		else {
			arguments.out.append(serializeJSON(left(arguments.stObject[arguments.propertyConfig.from], arguments.settings.maxFieldSize)));
		}
	}

	public void function processLongChar(required any out, required struct stObject, required struct propertyConfig, required struct settings) {
		processString(argumentCollection=arguments);
	}

	public void function processRichText(required any out, required struct stObject, required struct propertyConfig, required struct settings) {
		arguments.out.append(serializeJSON(left(rereplace(arguments.stObject[arguments.propertyConfig.from], "<[^>]+>", " ", "ALL"), arguments.settings.maxFieldSize)));
	}

	public void function processUUID(required any out, required struct stObject, required struct propertyConfig) {
		arguments.out.append('"#arguments.stObject[arguments.propertyConfig.from]#"');
	}

	public void function processArray(required any out, required struct stObject, required struct propertyConfig) {
		arguments.out.append('[ ');

		for (var i=1; i<=arrayLen(arguments.stObject[arguments.propertyConfig.from]); i++) {
			if (i neq 1) {
				arguments.out.append(', ');
			}

			arguments.out.append('"');
			arguments.out.append(arguments.stObject[arguments.propertyConfig.from][i]);
			arguments.out.append('"');
		}

		arguments.out.append(' ]');
	}

	public void function processList(required any out, required struct stObject, required struct propertyConfig) {
		var value = listToArray(arguments.stObject[arguments.propertyConfig.from]);

		arguments.out.append('[ ');

		for (var i=1; i<=arrayLen(value); i++) {
			if (i neq 1) {
				arguments.out.append(', ');
			}

			arguments.out.append(serializeJSON(value[i]));
		}

		arguments.out.append(' ]');
	}

	public void function processBoolean(required any out, required struct stObject, required struct propertyConfig) {
		if (arguments.stObject[arguments.propertyConfig.from]) {
			arguments.out.append("true");
		}
		else {
			arguments.out.append("false");
		}
	}

	public void function processWebskin(required any out, required struct stObject, required struct propertyConfig) {
		writeLog(file="debug", text=serializeJSON(arguments.stObject));
		var html = application.fapi.getContentType(arguments.stObject.typename).getView(stObject=arguments.stObject, webskin=arguments.propertyConfig.webskin, alternateHTML="");

		html = reReplace(html, "(?:m)^\s+", "", "ALL");
		html = reReplace(html, "[\n\r]+", "\n", "ALL");

		arguments.out.append(serializeJSON(html));
	}

	public void function processTypenameLabel(required any out, required struct stObject) {

		arguments.out.append(serializeJSON(application.fapi.getContentTypeMetadata(arguments.stObject.typename, "displayName", arguments.stObject.typename)));
	}

	public void function processFriendlyURL(required any out, required struct stObject) {

		arguments.out.append('"');
		arguments.out.append(application.fapi.getLink(type=arguments.stObject.typename, objectid=arguments.stObject.objectid));
		arguments.out.append('"');
	}

	public void function processStatus(required any out, required struct stObject) {
		if (structKeyExists(arguments.stObject, "status")) {
			arguments.out.append('"');
			arguments.out.append(arguments.stObject.status);
			arguments.out.append('"');
		}
		else {
			arguments.out.append('"approved"');
		}
	}


	/* API functions */
	public any function makeRequest(required string resource, string method, struct stQuery={}, string data="", numeric timeout=30, boolean throwOn404=true) {
		var item = "";
		var resourceURL = arguments.resource;
		var apiKey = "";
		var applicationID = application.fapi.getConfig("algolia", "applicationID");
		var subdomain = lcase(applicationID);

		if (arguments.method eq "") {
			if (len(arguments.data)) {
				arguments.method = "POST";
			}
			else {
				arguments.method = "GET";
			}
		}

		if (arguments.method eq "GET") {
			subdomain &= "-dsn";
		}

		if (arguments.method eq "GET" and reFind("^/indexes/[^/]+(/query|/queries|/facets|/browse)?", arguments.resource)) {
			// query request
			apiKey = application.fapi.getConfig("algolia", "queryAPIKey");
		}
		else {
			// admin request
			apiKey = application.fapi.getConfig("algolia", "adminAPIKey");
		}

		for (item in arguments.stQuery) {
			resourceURL &= (find("?", resourceURL) ? "&" : "?") & URLEncodedFormat(item) & "=" & URLEncodedFormat(arguments.stQuery[item]);
		}

		cfhttp(method=arguments.method, url="https://#subdomain#.algolia.net/1#resourceURL#", timeout=arguments.timeout) {
			cfhttpparam(type="header", name="X-Algolia-API-Key", value=apiKey);
			cfhttpparam(type="header", name="X-Algolia-Application-Id", value=applicationID);

			if (len(arguments.data)) {
				cfhttpparam(type="header", name="Content-Type", value="application/json");
				cfhttpparam(type="body", value=arguments.data);
			}
		}

		if (not reFindNoCase("^20. ",cfhttp.statuscode) and not reFindNoCase("^404 ",cfhttp.statuscode)) {
			throw(message="Error accessing Google API: #cfhttp.statuscode#", detail="#serializeJSON({
				'resource' = arguments.resource,
				'method' = arguments.method,
				'query_string' = arguments.stQuery,
				'body' = arguments.data,
				'resource' = 'https://#subdomain#.algolia.net/v1' & resourceURL,
				'response' = isjson(cfhttp.filecontent.toString()) ? deserializeJSON(cfhttp.filecontent.toString()) : cfhttp.filecontent.toString(),
				'responseHeaders' = duplicate(cfhttp.responseHeader)
			})#");
		}
		if (reFindNoCase("^404 ",cfhttp.statuscode)) {
			if (arguments.throwOn404) {
				throw(message="Error accessing Google API: #cfhttp.statuscode#", detail="#serializeJSON({
					'resource' = arguments.resource,
					'method' = arguments.method,
					'query_string' = arguments.stQuery,
					'body' = arguments.data,
					'resource' = 'https://#subdomain#.algolia.net/v1' & resourceURL,
					'response' = isjson(cfhttp.filecontent.toString()) ? deserializeJSON(cfhttp.filecontent.toString()) : cfhttp.filecontent.toString(),
					'responseHeaders' = duplicate(cfhttp.responseHeader)
				})#");
			}
			else {
				return {};
			}
		}

		return deserializeJSON(cfhttp.filecontent.toString());
	}

	public struct function customBatch(required string data) {
		var indexName = application.fapi.getConfig("algolia", "indexName");

		return makeRequest(
			method = "POST",
			resource = "/indexes/#indexName#/batch",
			data = arguments.data
		);
	}

	public struct function getSettings(string indexName=application.fapi.getConfig("algolia", "indexName")) {

		return makeRequest(
			method = "GET",
			resource = "/indexes/#arguments.indexName#/settings",
			throwOn404 = false
		);
	}

	public struct function setSettings(string indexName=application.fapi.getConfig("algolia", "indexName"), required string data, boolean forwardToReplicas=false) {

		return makeRequest(
			method = "PUT",
			resource = "/indexes/#arguments.indexName#/settings",
			stQuery = { forwardToReplicas = arguments.forwardToReplicas ? "true" : "false" },
			data = arguments.data
		);
	}


	/* Functions for public search */
	public string function generateSecuredApiKey(required struct query) {
		var privateApiKey = application.fapi.getConfig("algolia", "queryAPIKey");
		var queryStr = "";
		var key = "";

		for (key in listToArray(listSort(structKeyList(arguments.query), "text"))) {
			queryStr = listAppend(queryStr, "#key#=#algoliaURLEncode(arguments.query[key])#", "&");
		}

		var encodedQueryStr = lcase(binaryEncode(application.fc.lib.cdn.cdns.s3.HMAC_SHA256(queryStr, privateAPIKey.getBytes("UTF8")), "hex"));

		return binaryEncode((encodedQueryStr & queryStr).getBytes("UTF8"), 'Base64');
	}

	public string function algoliaURLEncode(required string input) {
		var result = URLEncodedFormat(arguments.input);

		result = replaceList(result, "%20,%2E,%2D,%2A,%5F", "+,.,-,*,_");

		return result;
	}

	public string function getBaseFilter() {
		var timestampNow = numberFormat(getTickCount() / 1000, "0");
		var statusFilter = [];
		var val = "";

		for (val in listToArray(request.mode.lValidStatus)) {
			arrayAppend(statusFilter, "status:#val#");
		}

		return arrayToList([
			"(#arrayToList(statusFilter, ' OR ')#)",
			"publishdate < #timestampNow#",
			"(expirydate > #timestampNow# OR expirydate = -1)"
		], " AND ");
	}

}