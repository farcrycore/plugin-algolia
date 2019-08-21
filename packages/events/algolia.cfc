<cfcomponent displayname="Archive" hint="Content archive functionality" output="false" component="fcTypes">

	<!--- The basic rule is: if publicly visible content is changed, archive first --->

	<cffunction name="saved" access="public" output="false" hint="Invoked immediately before DB is updated">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="oType" type="any" required="true" hint="A CFC instance of the object type" />
		<cfargument name="stProperties" type="struct" required="true" hint="The object" />
		<cfargument name="user" type="string" required="true" />
		<cfargument name="auditNote" type="string" required="true" />
		<cfargument name="bSessionOnly" type="boolean" required="true" />

		<cfset var stProps = duplicate(arguments.stProperties) />
		<cfset var lastupdatedby = "">
		<cfset var st = {} />

		<!--- do nothing while update app is happening --->
		<cfif NOT isDefined("application.bInit") OR application.bInit eq false>
			<cfreturn />
		</cfif>

		<!--- do nothing if it's a session-only update --->
		<cfif arguments.bSessionOnly>
			<cfreturn />
		</cfif>

		<!--- update index --->
		<cfif application.fc.lib.algolia.isIndexable(stProps)>		
			<cfset structappend(stProps, application.fapi.getContentObject(typename=stProps.typename, objectid=stProps.objectid), false) />
			<cfif StructKeyExists(stProps, 'status') AND stProps['status'] == 'approved'>
				<cfif request.mode.debug><cflog file="algolia-event" text="saved(#arguments.typename#): update index stProperties=#serializeJSON(arguments.stProperties)#"></cfif>
				<cfset application.fc.lib.algolia.importIntoIndex(stObject=stProps, operation="updated") />
			<cfelse>
				<cfif request.mode.debug><cflog file="algolia-event-draft" text="saved(#arguments.typename#): stProperties=#serializeJSON(arguments.stProperties)#"></cfif>
			</cfif>
		</cfif>
	</cffunction>

	<cffunction name="deleted" access="public" hint="I am invoked when a content object has been deleted">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="oType" type="any" required="true" hint="A CFC instance of the object type" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />
		<cfargument name="user" type="string" required="true" />
		<cfargument name="auditNote" type="string" required="true" />

		<cfif application.fc.lib.algolia.isIndexable(arguments.stObject)>
			
			<cfif request.mode.debug><cflog file="algolia-event" text="deleted(#arguments.typename#): stObject=#serializeJSON(arguments.stObject)#"></cfif>
			<cfset application.fc.lib.algolia.importIntoIndex(stObject=arguments.stObject, operation="deleted") />
		</cfif>
	</cffunction>

	<cffunction name="statusChanged" access="public" hint="I am invoked when a content object has been deleted">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="oType" type="any" required="true" hint="A CFC instance of the object type" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />
		<cfargument name="newStatus" type="string" required="true" />
		<cfargument name="previousStatus" type="string" required="true" />
		<cfargument name="auditNote" type="string" required="true" />

 		<cfif application.fc.lib.algolia.isIndexable(arguments.stObject)>
			<!--- if was approved, remove from index --->
			<cfif arguments.previousStatus == 'approved' AND arguments.newStatus != 'approved'>
				<cfif request.mode.debug><cflog file="algolia-event" text="statusChanged(#arguments.typename#) Removing from index [newStatus=#arguments.newStatus#|previousStatus=#arguments.previousStatus#]: stObject=#serializeJSON(arguments.stObject)#"></cfif>
				<cfset application.fc.lib.algolia.importIntoIndex(stObject=arguments.stObject, operation="deleted") />
			</cfif>

		</cfif> 
	</cffunction>

</cfcomponent>