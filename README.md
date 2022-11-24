Cache-MDX4JSON
==============

RESTful web api for MDX4JSON transformation (also JSONP and XML/A). Also supports requests about Dashboards and Widgets. Supports Caché 2014.1+.

Installation
-----------

1. Download Installer.cls.xml (from MDX4JSON folder in repository or releases page) and import it into any namespace (via Studio or SMP or `$System.OBJ.Load()`) 
2. Run in terminal (import namespace) under user with %All role: 

        Do ##class(MDX4JSON.Installer).setup()
        
Offline Installation
-----------

1. Download zip and unpack it.
2. Import Installer.cls.xml (from MDX4JSON folder in unpacked archive) and import it into any namespace (via Studio or SMP or `$System.OBJ.Load()`)
3. Run in terminal (same namespace as 2) under user with %All role: 

        Set pVars("SourceDir") = {SourceDir}
        Do ##class(MDX4JSON.Installer).setup(.pVars)

  where: 
    
      {SourceDir} is a directory where you unpacked zip \ MDX4JSON (see 1).


For information on how to work with this RESTful web API please refer to included documentation.

What Installer does
-----------
Regardless of installation method chosen, here's the list (by the order of appearance) of what installer does:

1. If `Namespace` variable is undefined, set it to `MDX4JSON`
2. Create `MDX4JSON` role
2. If `Namespace` does not exist then create it
3. If `SourceDir` is provided then import and compile all files from there. Otherwise download import and compile all required files from [GitHub](https://github.com/intersystems-ru/Cache-MDX4JSON/)
4. If `/Namespace` web application does not exist then create it and give it MDX4JSON role
5. If [%All namespace](http://docs.intersystems.com/cache20152/csp/docbook/DocBook.UI.Page.cls?KEY=GSA_config#GSA_config_namespace_addmap_all) (used for mapping purposes) does not exist then create it and map MDX4JSON package and ^MDX4JSON global there
6. Map MDX4JSON package and ^MDX4JSON global into SAMPLES namespace
7. If `User` and `Password` variables are provided, then create User and give him MDX4JSON role

Additional installation parameters
-----------

As a first parameter to `Do ##class(MDX4JSON.Installer).setup(.pVars)` you can pass pVars - a local array of additional variables (see sample in Offline Installation step 3).

- `Namespace` is a namespace you want to install MDX4JSON to (Not namespace with dashes). If it does not exist it would be created automatically. If it does exist only MDX4JSON package would be overwritten. WebApplication would be named `/Namespace`. Strongly not recommended to change the default. [MDX4JSON]
- `User` is a Caché user to create or modify. He will be given SELECT access to %DeepSee_Dashboard.Definition table in `Namespace`
- `Password` must be supplied alongside User parameters
- `SourceDir` - all xmls from this directory would be imported and compiled
- `Import` - import code from GitHub or `SourceDir`, defaults to 1, set to 0 to skip import


Update
-----------

1.  Run in terminal (namespace where you installed MDX4JSON): 

        Do ##class(MDX4JSON.Installer).Update()
	  
You can also supply parameters such as fork, desired branch/commit, target namespace, authorization information. Please refer to Caché documentation of MDX4JSON.Installer class for correct syntax. 

Uninstall
-----------

1.  Run in terminal (any namespace from where MDX4JSON package can be accessed): 

        Do ##class(MDX4JSON.Installer).Uninstall()
	  
This action would delete MDX4JSON namespace, database (with physical directory) and web application. Mappings and `%DB_MDX4JSON` role and resource would also be deleted.

Requests
-----------

These are the possible requests to web application (add param ?Namespace={Desired Namespace} to query another namespace cubes

| URL                         | Type | Body (JSON)                 | Response  | Description                    |
|-----------------------------|------|-----------------------------|-----------|--------------------------------|
| MDX                         | POST | { "MDX":"QUERY" }           | JSON      | Results of MDX execution       |
| MDX4JSONP                   | POST | { "MDX":"QUERY" }           | JSONP     | Results of MDX execution       |
| MDXDrillthrough             | POST | { "MDX":"QUERY" }           | JSON      | Results of MDX execution       |
| MDX2XMLA                    | POST | { "MDX":"QUERY" }           | XMLA      | Results of MDX execution       |
| Dashboards                  | GET  |                             | JSON      | All dashboards                 |
| Dashboards                  | POST | {Folder:"FolderName"}       | JSON      | All dashboards in FolderName. Empty FolderName for root scope.|
| Dashboard                   | POST | {Dashboard:"DashboardName"} | JSON      | All widgets in a dashboard, with filters as part of dashboard|
| Widgets                     | POST | {Dashboard:"DashboardName"} | JSON      | All widgets in a dashboard, with filters as part of widgets  |
| DataSource                  | POST |{DataSource:"Pivot fullname"}| JSON      | All info about Pivot           |
| Action/:Cube/:Action        | POST |{[context object](http://docs.intersystems.com/ens20152/csp/docbook/DocBook.UI.Page.cls?KEY=D2IMP_ch_action#D2IMP_action_context_info)}             | JSON      | Execute cube action            |
| Filters                     | POST |{ "DataSource": "DataSourceName.ext", "Values":1, Search:"SearchTerm", "RelatedFilters": [ {"Filter": "Filter", "Value": "Value"}]}| JSON   | All filters for DeepSee DataSource (cube, pivot, kpi, metric) with values (if Values = 1, set to 0 or omit otherwise). If Search is not empty only filter values, containing search term would be returned. RelatedFilters - other filters and their values to limit search.|
| Format                      | GET  |                             | JSON      | Default formatting             |
| TermList                    | POST | {"TermList":"TermListName"} | JSON      | Termlist key-value array       |
| Config                      | POST |{"Application":"AppName", "Config":"value"}| JSON      | Set config for arbitrary application for current user|
| Config/:Application         | GET  | {"Application":"AppName"}   | JSON      | Get config for Application for current user|
| Favorites                   | GET  |                             | JSON      | Array of current user favorites|
| Favorites/:Item             | POST |                             | JSON      | Add favorite item              |
| Favorites/:Item             |DELETE|                             | JSON      | Remove item from favorites     |
| PivotVariables/:Cube        | GET  |                             | JSON      |Get all pivot variables for cube|
| Test                        | GET  |                             | JSON      | Test info                      |
| Logout                      | GET  |                             | JSON      | Close session                  |

Example
-----------

Request URL: http://localhost:57772/MDX4JSON/MDX?Namespace=Samples

Request type: POST

Request body:

    {"MDX": "SELECT NON EMPTY [Product].[P1].[Product Category].Members ON 0,NON EMPTY [Outlet].[H1].[Region].Members ON 1 FROM [HoleFoods]"} 
    
[Result](https://github.com/intersystems-ru/Cache-MDX4JSON/wiki/MDX-output)

Please note that corresponding cube must be compiled and built beforehand.

Localization
-----------

If requested data or meta-information is available in several different languages, you can choose one, by supplying Accept-Language header to your HTTP request, formed in accordance with [RFC 2616](http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4). 

Troubleshooting
-----------

If something goes wrong, server must report an error in the following format {Error : "Error description"}, and usually that is a good indicator of what went wrong. If you received an error in another format or an error without "Error description" please file an issue [here](https://github.com/intersystems-ru/Cache-MDX4JSON/issues/8).

| Problem                     | Solution                         | 
|-----------------------------|----------------------------------|
| CSP Error                   | User does not have enough rights. Configure User or Webapplication roles  | 
| Authenticated access        | Web application must have password access, resource for database with MDX4JSON must have public RW rights enabled|
| No dashboards               | Configure roles. Change [dashboard scope](https://github.com/intersystems-ru/Cache-MDX4JSON/issues/10)|
| DeepSee errors              | Build and compile DeepSee cube(s)|
| MDX errors                  | Don't forget to escape JSON strings [here](http://json.org/string.gif) |
| Installation errors		  | Usually problems arise when installation is run under user without %All permissions. To repair the install rerun it under correct user. If the error persists then file an issue with installation log (terminal output) attached|


Debugging
-----------

Use $$$Debug macro. It would evaluate as true only if there is a "Debug" URL parameter present. Example request URL:

        http://localhost:57772/MDX4JSON/MDX?Namespace=Samples&Debug
		
Use with post conditional expressions, or other flow control statements:

		w:$$$Debug "debugging"
		if $$$Debug { w "debugging" } else { w "not debugging"}
		
Also available are $$$Public and $$$Private macros. Evaluates to true based on request port (80 and 443 are public, private otherwise).

Querying
-----------

Querying this project is done via REST web client. It may be a standalone application or a browser plug-in, a number of different solutions are available.

For Google Chrome, install [Advanced REST client](https://chrome.google.com/webstore/detail/advanced-rest-client/hgmloofddffdnphfgcellkdfbfbjeloo?hl=en) extension.
For Firefox, install [REST client](https://addons.mozilla.org/en-US/firefox/addon/restclient/) extension.
Open installed extension and set the following parameters:

- URL to required web api method, e.g.: `http://serverip:port/MDX4JSON/Dashboard?Namespace=Samples`
- Request type to `GET` or `POST`
- Payload to `{"Dashboard":"Listing with Filters.dashboard"}`
- Content-Type to `application/json` (only in Advanced REST client)

Press Send button to view results (depending on your server configuration you may be asked to provide valid login/password to access MDX4JSON api).

Settings
-----------

User can save and get arbitrary settings for an abstract application (usually - Namespace). Settings are accessible throughout the system.
To set a setting for a user, execute: `do ##class(MDX4JSON.Users).SetConfig(Application, SettingsValue, Username)` or send a request at a corresponding `POST /Config` with the JSON body containing `Application` property and `Config` property which can be a string or a JSON object. Note that in a WEB context user is not allowed to specify a username, it's calculated automatically. 
To get a setting  for an abstract application  `write ##class(MDX4JSON.Users).GetConfig(Application, Username)` or send a request at a corresponding `GET /Config/:Application` path.

User can have a `MDX4JSONSettings` role which allows him to get/set a default setting for an application. If the user (any user) does not have a setting for an Application, the default setting for an application would be used.

Calling MDX4JSON from another server
-----------

Here's an [example](https://github.com/eduard93/Utils/blob/master/Utils/MDX4JSON.cls.xml).


Development
-----------

To develop MDX4JSON you need:

1. Install MDX4JSON in `MDX4JSON` namespace
2. Install [Cache-Tort-Git](https://github.com/intersystems-ru/cache-tort-git)
3. In terminal, `MDX4JSON` namespace execute:

		set ^Git("settings","hook") = $lb("MDX4JSON.Tests","OnCommit")
		set ^Git("settings","groupByFolder") = 1

4. Activate Cache-Tort-Git for `MDX4JSON` namespace
5. Commit all changes via Studio


KPI
-----------

To use KPIs and display row name add this method to KPI class 

    ClassMethod %OnGetKPIPropertyInfo(ByRef pList As %String, pPropNo As %Integer, pModelId As %String = "") As %Status
    {
	    Set pPropNo = pPropNo + 1
	    Set pList(pPropNo) = "%series"
	    Set pList(pPropNo, "defaultValue") = ""
	    Set pList(pPropNo, "columnNo") = pPropNo
	    Quit $$$OK
    }

	
Postman
-----------

You can use [Postman](https://www.getpostman.com/) to query MDX4JSON API. [Collection](MDX4JSON.postman_collection.json). [Environment](CACHE.postman_environment.json).


	