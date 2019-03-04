# Algolia Plugin
Implements site search using the Algolia service

## Setup

Add this to your nginx config:

    location /algolia {
        alias /var/www/farcry/plugins/algolia/www;
    }

## Configuration

This plugin is configured by setting a JSON packet in the `algolia.indexConfig`config. Typically this would be set in `_serverSpecificVarsAfterInit.cfm`. For example:

    <cfset application.fapi.setConfig("algolia", "indexConfig", serializeJSON({
        "types": {
            "dmHTML": { "title":{}, "teaser":{}, "body":{} }
        },
        "settings": {
            
        }
    }), true) />

The following sections describe the values this config should contain:

### Settings

| Key          | Notes                                                     |
| ------------ | --------------------------------------------------------- |
| maxFieldSize | The maximum number of characters for any field. Def: 5000 |

### Types

This should contain an entry for each content type you need to index. The value of this is an empty struct (to index all properties of that type) or a struct with keys for all the properties you need to be indexed.

> TODO: what do these property keys need to contain

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
    ADD datetimeLastUpdated_bak DATETIME NOT NULL;
    
    UPDATE contentType
    SET datetimeLastUpdated_bak = datetimeLastUpdated;
    
    ALTER TABLE contentType
    ADD `inc` INT NOT NULL AUTO_INCREMENT UNIQUE;
    
    UPDATE contentType
    SET datetimeLastUpdated = DATE_ADD(date(datetimeLastUpdated), INTERVAL `inc` SECOND);
    
    ALTER TABLE contentType
    DROP COLUMN `inc`;

2) Run the import process from the webtop.

3) Restore the values afterwards with this:

    UPDATE contentType
    SET datetimeLastUpdated = datetimeLastUpdated_bak;
    
    ALTER TABLE contentType
    DROP COLUMN `datetimeLastUpdated_bak`;

