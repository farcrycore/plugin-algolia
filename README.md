# Algolia Plugin
Implements site search using the Algolia service

## Setup

Add an alias to your web server config.

**NGINX config**
```
    location /algolia {
        alias /var/www/farcry/plugins/algolia/www;
    }
```

**Apache config**
```
   Alias "/algolia" "/var/www/farcry/plugins/algolia/www"
```


## Configuration
There are several Algolia service specific keys you will need to get up and running.  You can set these through the webtop, codebase or via environment variables.

| Property     | Notes                                                     |
| ------------ | --------------------------------------------------------- |
| applicationID | Algolia service application ID for your account. |
| adminAPIKey | Algolia Admin API key. |
| queryAPIKey | Algolia Search API Key. |
| indexName | Name for the base index in Algolia. Additional indexes can be added but they will all be prefixed with this value. |

Recommend using ENV variables, especially the `indexName`, as these may vary between environments.

For example, through ENV via `docker-compose`:
```
    - "FARCRY_CONFIG_ALGOLIA_APPLICATIONID=XXXTOPSECRETXXX"
    - "FARCRY_CONFIG_ALGOLIA_ADMINAPIKEY=XXXTOPSECRETXXX"
    - "FARCRY_CONFIG_ALGOLIA_QUERYAPIKEY=XXXTOPSECRETXXX"
    - "FARCRY_CONFIG_ALGOLIA_INDEXNAME=stage_myapp"
```

This plugin is configured by setting a JSON packet in the `algolia.indexConfig`config, see examples below. Typically this would be set in `_serverSpecificVarsAfterInit.cfm`. 

For example:
```
    <cfset application.fapi.setConfig("algolia", "indexConfig", serializeJSON({
        "types": {
            "dmHTML": { "title":{}, "teaser":{}, "body":{} }
        },
        "settings": {  
        }
    }), true) />
```


Required index properties; title, teaser for example UI map them to content type properties
Need all index properties to have the same name if used across multiple content types in a single index.

Implied content type property name from index name:
"title":{ "from":"title", "type":"string" }
(the data type "type" defaults to fttype for the cfproperty; fall back to string)
(from is optional; defaults to the data type function value)

Plugin data type function generic is processObject() and it determines and calls standard functions that map to standard farcry data types and special dynamic data types like processFriendlyURL and processWebskin.
"speciallabel":{ "type":"Webskin", "webskin":"myfunkywebskinview" }

Custom data type function possible:
"acategorylabels":{ "from":"parentUUID", "type":"parentlabel" }

acategorylabel (algolia index property name)
has a value from "parentUUID" processed by the custom function lib.algolia.parentlabel()
function gets; stobject, config properties, and java string buffer

You can add as many properties as you like to the config struct for each content type; they just get passed into the processFunction as arguments.


The following sections describe the values this config should contain:

### Settings

| Key          | Notes                                                     |
| ------------ | --------------------------------------------------------- |
| maxFieldSize | The maximum number of characters for any field. Def: 5000 |
| attributesForFaceting | Array of properties available for faceted search. |
| ordering | Order of each specific index; defaults to `bfeatured desc` but might be used to create alternate index order by date. |

### Types

This should contain an entry for each content type you need to index. The value of this is an empty struct (to index all properties of that type) or a struct with keys for all the properties you need to be indexed.

> TODO: what do these property keys need to contain


### Examples

**Most Basic Functioning Example**
```
    <cfset application.fapi.setConfig("algolia", "indexConfig", serializeJSON({
        "types": {
            "dmHTML": { "title":{}, "teaser":{}, "body":{} }
        },
        "settings": {  
        }
    }), true) />
```

**Complex Config with Special Cases**

```
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

The initial import of data requires that datetimeLastUpdated be unique. If you have imported data into that table in the past, or if you insert a lot of data, you may have duplicate dates in this column.

There is an option in the Algolia status page to disambiguate this field automatically, but it does change the times of those values. It is basically doing this:

    ALTER TABLE contentType
    ADD `inc` INT NOT NULL AUTO_INCREMENT UNIQUE;
    
    UPDATE contentType
    SET datetimeLastUpdated = DATE_ADD(date(datetimeLastUpdated), INTERVAL `inc` SECOND);

    ALTER TABLE contentType
    DROP COLUMN `inc`;

If you want to preserve these dates, you can:

1) Do something like this to make a copy of the field, and disambiguate `datetimeLastUpdated`:

    ALTER TABLE contentType
    ADD datetimeLastUpdated_bak DATETIME NOT NULL,
    ADD `inc` INT NOT NULL AUTO_INCREMENT UNIQUE;
    
    UPDATE contentType
    SET datetimeLastUpdated_bak = datetimeLastUpdated,
        datetimeLastUpdated = DATE_ADD(date(datetimeCreated), INTERVAL `inc` SECOND);
    
    ALTER TABLE contentType
    DROP COLUMN `inc`;

2) Run the import process from the webtop.

3) Restore the values afterwards with this:

    UPDATE contentType
    SET datetimeLastUpdated = datetimeLastUpdated_bak;
    
    ALTER TABLE contentType
    DROP COLUMN `datetimeLastUpdated_bak`;

