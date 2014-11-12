Cache-MDX2JSON
==============

RESTful web api for MDX2JSON transformation (also JSONP and XML/A). Also supports requests about Dashboards and Widgets.

Installation
-----------

1. Download zip and unpack it.
2. Run in terminal (any namespace): 

        do  ##class(%Installer.Installer).InstallFromCommandLine("{SourceDir}\Installer.cls.xml","Namespace={Namespace},SourceDir={SourceDir}",0)

  where: 
  
      {Namespace} is a namespace you want to install to. If it does not exist it would be created automatically. If it does exist only MDX2JSON package would be overwritten.
  
      {SourceDir} is a directory where you unpacked zip \ MDX2JSON (see 1).
On this step installer would create (if needed) {Namespace}, import source code and compile it, create required web application, and map MDX2JSON package to %All namespace (which will be created if does not exist).
3. Give the correct roles to /{Namespace} webapplication for it to be able to query desired cubes.


For information on how to work with this RESTful web API please refer to included documentation.

Requests
-----------

These are the possible requests to web application (add param ?Namespace={Desired Namespace} to query another namespace cubes

| URL                         | Type | Body (JSON)                 | Response  | Description                    |
|-----------------------------|------|-----------------------------|-----------|--------------------------------|
| MDX                         | POST | { "MDX":"QUERY" }           | JSON      | Results of MDX execution       |
| MDX2JSONP                   | POST | { "MDX":"QUERY" }           | JSONP     | Results of MDX execution       |
| MDXDrillthrough             | POST | { "MDX":"QUERY" }           | JSON      | Results of MDX execution       |
| MDX2XMLA                    | POST | { "MDX":"QUERY" }           | XMLA      | Results of MDX execution       |
| Dashboards                  | GET  |                             | JSON      | All dashboards                 |
| Widgets                     | POST | {Dashboard:"DashboardName"} | JSON      | All widgets in a dashboard     |
| FilterValues/:cube         | GET  |                             | JSON      | All filters for DeepSee Cube   |
| FilterValues/:cube/:filter | GET  |                             | JSON      | All possible values for filter |
| DrillInfo                  | POST | { cubeName: "HoleFoods", queryKey: "ru512140103", sortDir: "ASC", sortColumn: 0, row: 1 } | JSON      | Returns drilldown information |
| Test                        | GET  |                             | plaintext | Test info                      |

Example
-----------

Request Url: http://localhost:57772/MDX2JSON/MDX?Namespace=Samples

Request type: POST

Request body:

    {"MDX": "SELECT NON EMPTY [Product].[P1].[Product Category].Members ON 0,NON EMPTY [Outlet].[H1].[Region].Members ON 1 FROM [HoleFoods]"} 
    
Result: http://pastebin.com/XddMUPHX
