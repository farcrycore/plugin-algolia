# Algolia Plugin
Implements site search using the Algolia service

## Setup

Add an alias to your web server config.

### NGINX config

```json
    location /algolia {
        alias /var/www/farcry/plugins/algolia/www;
    }
```

### Apache config

```apache
   Alias "/algolia" "/var/www/farcry/plugins/algolia/www"
```

## Configuration

There are several Algolia service specific keys you will need to get up and
running.  You can set these through the webtop, codebase or via environment
variables.

| Property      | Notes                                                                                                              |
| ------------- | ------------------------------------------------------------------------------------------------------------------ |
| applicationID | Algolia service application ID for your account.                                                                   |
| adminAPIKey   | Algolia Admin API key.                                                                                             |
| queryAPIKey   | Algolia Search API Key.                                                                                            |
| indexName     | Name for the base index in Algolia. Additional indexes can be added but they will all be prefixed with this value. |

Recommend using ENV variables, especially the `indexName`, as these may vary between environments.

For example, through ENV via `docker-compose`:

```docker
    - "FARCRY_CONFIG_ALGOLIA_APPLICATIONID=XXXTOPSECRETXXX"
    - "FARCRY_CONFIG_ALGOLIA_ADMINAPIKEY=XXXTOPSECRETXXX"
    - "FARCRY_CONFIG_ALGOLIA_QUERYAPIKEY=XXXTOPSECRETXXX"
    - "FARCRY_CONFIG_ALGOLIA_INDEXNAME=stage_myapp"
```

This plugin is configured by setting a JSON packet in the `algolia.indexConfig`
config, see examples below. Typically this would be set in `_serverSpecificVarsAfterInit.cfm`.

For example:

```coldfusion
    <cfset application.fapi.setConfig("algolia", "indexConfig", serializeJSON({
        "types": {
            "dmHTML": { "title":{}, "teaser":{}, "body":{} }
        },
        "settings": {  
        }
    }), true) />
```

### Index configuration

Indexes support the following settings:

| Key          | Notes                                                     |
| ------------ | --------------------------------------------------------- |
| maxFieldSize | The maximum number of characters for any field. Def: 5000 |
| attributesForFaceting | Array of properties available for faceted search. |
| searchableAttributes | Array of properties available for searching. [Algolia Documentation](https://www.algolia.com/doc/api-reference/api-parameters/searchableAttributes/)|
| ordering | Struct specifying the ordering options |

#### Ordering

Ordering in Algolia is done by using read-only replicas of the default index.
Adding order options to this struct will result in replicas being created in
Algolia with the name `baseindexname_ordername`.

You can override the order of the base index by setting a `default` order. The
default order is search relevance, and this should only be overriden if you do
not have need of that type of ordering.

Order values should be in the format `fieldname [asc|desc]`.

Example:

```json
    {
        "ordering": {
            "price_asc"  : "productsellprice asc",
            "price_desc" : "productsellprice desc",
            "title_asc"  : "title asc",
            "title_desc" : "title desc"
        }
    }
```

### Field configuration format

Each algolia field is highly configurable. Empty field configs are indexed from
the matching content type property. e.g. the above example inserts the dmHTML
`title` property as the Algolia `title` field, as the default format of an empty
algolia field is Property with the configs automatically generated from the
property metadata.

However there are many ways to generate the value sent to algolia, based on the
frmat of the field config:

| Format   | Structure                         | Notes                                                                        |
| -------- | --------------------------------- | ---------------------------------------------------------------------------- |
| Property | `{ }`                             | The field is created from the property of the same name as the Algolia field |
| Function | `{ "processFn" }` OR `{ "type" }` | The field is created using the specified function                            |
| Value    | `{ "value" }`                     | The specified value is used for this field                                   |

#### Property

All Property formats support this additional configs:

| Config      | Notes                                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------------ |
| `from`      | Overrides which property this field is generated from                                                              |
| `type`      | Overrides the type - by default this is automatically generated from the ftType or type of the property            |
| `processFn` | This is a function name, either in the `algolia` library or in the content type - by default it is `process[Type]` |

An empty field config is expanded automatically to:

```json
    {
        "fieldname": { "from":"fieldname", "type":"ftType/type" }
    }
```

The following types are supported in the plugin.

| Type          | Notes                                                                                                            |
| ------------- | ---------------------------------------------------------------------------------------------------------------- |
| DateTime      | Converted to epoch time, or -1 if the field contains no valid date                                               |
| DateAsString  | Formats to `d mmmm yyyy` format, or an empty string if the field contains no valid date                          |
| Numeric       | Formats as an unquoted number                                                                                    |
| Integer       | Formats as an unquoted integer                                                                                   |
| String        | Formats as rich text with markup removed if it is a rich text property                                           |
| LongChar      | Same as String                                                                                                   |
| RichText      | Removes markup from property value                                                                               |
| UUID          | Formats as a quoted string                                                                                       |
| Array         | Formats as an array of UUID strings                                                                              |
| ArrayAsLabels | Looks up the content matching the UUIDs and formats as an array of the labels                                    |
| List          | Formats as an array of strings                                                                                   |
| Boolean       | Uses a truthy check and formats as `true` or `false`                                                             |
| File          | Converts the file path in the property to a value usable on the front end. May be a CDN path if CDNs are in use. |
| Image         | Same as File                                                                                                     |

You can add additional types to your project by extending `farcry.plugins.algolia.packages.lib.algolia`
into your own project, and adding functions named `processNewType`. Use the
functions in the plugin as examples of how these funtions should work.

#### Function

`processFn` defaults to `process[type]` and in that sense they are
interchangeable. The only real difference between a Property and Function
field config is that the Types specified in the Property section only work if
a valid `from` config is provided. The following types do not use the `from`
value though they may use content type properties.

| Type          | Notes                                                                                                                               |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Webskin       | The `webskin` config must also be provided, specifying the content type webskin to render for the object and use as the field value |
| TypenameLabel | Uses the display name of the content type as field value                                                                            |
| FriendlyURL   | Uses the objects friendly URL as the field value                                                                                    |
| Status        | Uses the objects status as the field value, or `approved` if the content type does not have status                                  |

### Default index properties

The following fields are added to every index config that does not include it
explicitly. They can be used in Algolia search result templates without any
additional configuration.

| Field              | Notes                                                                   |
| ------------------ | ----------------------------------------------------------------------- |
| `objectid`         | The object's `objectid                                                  |
| `typename`         | From the content type name                                              |
| `typenameLabel`    | The display name of the content type                                    |
| `status`           | The object's status, or `approved` if it does not have status           |
| `publishDate`      | The object's `publishDate`, or `-1` if it does not have one             |
| `publishDateLabel` | The object's `publishDate` or `datetimeCreated` in `d mmmm yyyy` format |
| `expiryDate`       | The object's `expiryDate`, or `-1` if it does not have one              |
| `url`              | The object's URL                                                        |

### Common index properties

Properties that are used in the template displayed to users should be common
across all the content types indexed. e.g. `title`, `teaser`. In some cases
that will mean that you need to rename a property for the index. An example of
how to do this:

```json
    {
        "title": { "from":"name" }
    }
```

### Custom content type processing

In some cases it may be useful to override the way a content type gets
processed. For example, you are adding many fields and it is more performant
to add them all from one query instead of one query per field.

You can do this by adding a function to the content type named `processObject[IndexName]`.
This function is passed the same arguments as the `processObject` function in
the `algolia` library.

### Complex example with special cases

```coldfusion
<cfset application.fapi.setConfig("algolia", "indexConfig", serializeJSON({
    "types": {
        "dspPage": { "title":{}, "parentUUID":{}, "body":{}, "siteID":{}, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" } },
        "yafEvent": { "siteID":{}, "title":{}, "parentUUID":{}, "acategorylabels":{ "from":"parentUUID", "type":"parentlabel" }, "publishDate":{}, "publishDateLabel":{ "from":"publishDate", "type":"dateAsString" }, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" }, "location":{}, "venue":{}, "link":{}, "body":{}, "teaser":{}, "contactCompany":{}, "contactName":{}, "contactEmail":{}, "contactPhone":{}, "bPublication":{} },
        "yafMagazine": { "siteID":{}, "title":{}, "teaser":{}, "yearlabel":{ "type":"yearlabel" } },
        "yafPhotoCompetition": { "siteID":{}, "title":{}, "parentUUID":{}, "acategorylabels":{ "from":"parentUUID", "type":"parentlabel" }, "teaser":{}, "body":{}, "aCategories":{}, "body2":{}, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" } },
        "yafPhotoCompetitionEntry": { "siteID":{}, "yafCompID":{}, "acategorylabels":{ "from":"yafCompID", "type":"parentlabel" }, "teaser":{}, "photographer":{}, "lastName":{}, "email":{}, "suburb":{}, "country":{}, "title":{}, "description": {}, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" } },
        "yafPhotoCompetitionEntryPhoto": { "siteID":{}, "title":{}, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" } },
        "dspArticle": { "title":{}, "parentUUID":{}, "acategorylabels":{ "from":"parentUUID", "type":"parentlabel" }, "publishDate":{}, "publishDateLabel":{ "from":"publishDate", "type":"dateAsString" }, "authorUUID":{}, "body":{}, "teaser":{}, "seoTitle":{}, "seoDescription":{}, "seoKeywords":{}, "siteID":{}, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" } },
        "dirCompany": { "status":{ "processFn":"processStatus" }, "siteID":{}, "parentUUID":{}, "listingType":{}, "bFeatured":{}, "datetimeLastOwnerUpdate":{}, "title":{ "from":"name" }, "teaser":{}, "aCategories":{}, "aCategoryLabels":{ "from":"aCategories", "type":"arraylabels" }, "phone":{}, "fax":{}, "address1":{}, "address2":{}, "suburb":{}, "state":{}, "postcode":{}, "abn":{}, "contact":{}, "websiteURL":{}, "facebookURL":{}, "twitterID":{}, "instagramID":{}, "email":{}, "description":{}, "mailingAddress1":{}, "mailingAddress2":{}, "mailingSuburb":{}, "mailingState":{}, "mailingPostcode":{}, "internationalAddress1":{}, "internationalAddress2":{}, "internationalSuburb":{}, "internationalCountry":{}, "internationalState":{}, "internationalPostcode":{}, "normalizedname":{}, "capabilities":{}, "yearlabel":{ "type":"yearlabel" }, "datebreakdown": { "type":"datehierarchy" } }
    },
    "settings": {
        "attributesForFaceting": [ "filterOnly(siteid)", "acategorylabels", "yearlabel", "datebreakdown" ],
        "searchableAttributes": [ "title,teaser", "unordered(email)", "ordered(address1,address2)" ],
        "ordering": {
            "publishdate_desc": "publishdate desc"
        }
    },
    "alternateIndexes": {
        "company": {
            "types": {
                "dirCompany": { "status":{ "processFn":"processStatus" }, "siteID":{}, "parentUUID":{}, "listingType":{}, "bFeatured":{}, "datetimeLastOwnerUpdate":{}, "title":{ "from":"name" }, "teaser":{}, "aCategories":{}, "aCategoryLabels":{ "from":"aCategories", "type":"arraylabels" }, "phone":{}, "fax":{}, "address1":{}, "address2":{}, "suburb":{}, "state":{}, "postcode":{}, "abn":{}, "contact":{}, "websiteURL":{}, "facebookURL":{}, "twitterID":{}, "instagramID":{}, "email":{}, "description":{}, "mailingAddress1":{}, "mailingAddress2":{}, "mailingSuburb":{}, "mailingState":{}, "mailingPostcode":{}, "internationalAddress1":{}, "internationalAddress2":{}, "internationalSuburb":{}, "internationalCountry":{}, "internationalState":{}, "internationalPostcode":{}, "normalizedname":{}, "capabilities":{}, "thumbnailLogo":{}, "hasthumbnail":{ "processFn":"processHasThumbnail" } }
            },
            "settings": {
                "attributesForFaceting": [ "filterOnly(siteid)", "filterOnly(parentuuid)", "filterOnly(acategories)", "acategorylabels", "filterOnly(parentuuid)" ],
                "ordering": {
                    "default": "bfeatured desc",
                    "publishdate_desc": "bfeatured desc,publishdate desc"
                }
            }
        }
    }
}), true) />
```

## Disambiuating Dates

The initial import of data requires that datetimeLastUpdated be unique. If you
have imported data into that table in the past, or if you insert a lot of data,
you may have duplicate dates in this column.

There is an option in the Algolia status page to disambiguate this field
automatically, but it does change the times of those values. It is basically
doing this:

```sql
    ALTER TABLE contentType
    ADD `inc` INT NOT NULL AUTO_INCREMENT UNIQUE;

    UPDATE contentType
    SET datetimeLastUpdated = DATE_ADD(date(datetimeLastUpdated), INTERVAL `inc` SECOND);

    ALTER TABLE contentType
    DROP COLUMN `inc`;
```

If you want to preserve these dates, you can:

1. Do something like this to make a copy of the field, and disambiguate
   `datetimeLastUpdated`:
    ```sql
        ALTER TABLE contentType
        ADD datetimeLastUpdated_bak DATETIME NOT NULL,
        ADD `inc` INT NOT NULL AUTO_INCREMENT UNIQUE;

        UPDATE contentType
        SET datetimeLastUpdated_bak = datetimeLastUpdated,
            datetimeLastUpdated = DATE_ADD(date(datetimeCreated), INTERVAL `inc` SECOND);

        ALTER TABLE contentType
        DROP COLUMN `inc`;
    ```

2. Run the import process from the webtop.

3. Restore the values afterwards with this:

    ```sql
        UPDATE contentType
        SET datetimeLastUpdated = datetimeLastUpdated_bak;

        ALTER TABLE contentType
        DROP COLUMN `datetimeLastUpdated_bak`;
    ```
