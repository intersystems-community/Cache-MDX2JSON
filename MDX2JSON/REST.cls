Include MDX2JSON.MDX2JSON

/// Class for REST-like web api for MDX2JSON transformation (and XML/A).<br>
/// Example: send HTTP POST request to web application with Dispatch class <b>MDX2JSON.REST</b>
/// with body: { "MDX":"QUERY" }, where QUERY is a correct MDX statement, ex:  <br>
/// {<br>
/// 		"MDX": "SELECT NON EMPTY [Product].[P1].[Product Category].Members ON 0,NON EMPTY [Outlet].[H1].[Region].Members ON 1 FROM [HoleFoods]"<br>
/// } <br>
/// You can send requests to:<br> <ul>
/// 	<li>webapplication/Test - to get test info, %request, %response and %session</li>
/// 	<li>webapplication/MDX - to get result in JSON format for MDX query</li>
/// 	<li>webapplication/MDXDrillthrough - to get resulting listing in JSON format for MDX Drillthrough query</li>
/// 	<li>webapplication/MDX2XMLA - to get result in XML/A format for MDX query</li>
/// </ul>
/// 
/// Dashboard related requests are:
///  <ul>
/// 	<li>webapplication/Dashboards - get all dashboards in a namespace (GET request).</li>
/// 	<li>webapplication/Dashboards - get folder specific (recursively) dashboards in a namespace (POST request with {Folder:"FolderName"} body) ).</li>
/// 	<li>webapplication/Dashboard - get all dashboard widgets (POST request with {Dashboard:"DashboardName"} body) with filters as part of dashboard.</li>
/// 	<li>webapplication/Widgets - get all dashboard widgets (POST request with {Dashboard:"DashboardName"} body) with filters as part of widgets.</li>
/// </ul>
/// To get information about possible datasource (cube, pivot, kpi, metric) filters and filters' values:<br><ul>
/// 	<li>webapplication/Filters - Same but with POST { "DataSource":"DataSourceName.ext","Values":0, Search:"SearchTerm"} body. If values = 1, then filters' values would also be provided. If Search is not empty only filter values, containing search term would be returned.</li>
/// </ul>
/// 
/// To get information about pivot:<br><ul>
/// 		<li>webapplication/DataSource- to get info about pivot (POST {DataSource:"Name of DS"})</li> </ul>
/// 
/// To get information about system-wide defaults (format):<br><ul>
/// 		<li>webapplication/Format - to get info about system-wide defaults (format). GET request </li> </ul>
/// 
/// You can add a param Namespace to request to execute MDX in desired namespace (MDX2JSON package must be mapped to that namespace):<br>
/// webapplication/MDX?Namespace=Samples<br>
/// 
/// Example: send HTTP GET request to web application with Dispatch class <b>MDX2JSON.REST</b> and URL:<br>
/// /FilterValues/HoleFoods/[DateOfSale].[Actual].[MonthSold] -  to get information about possible values of [DateOfSale].[Actual].[MonthSold] in HoleFoods Cube.<br>
/// 
Class MDX2JSON.REST Extends MDX2JSON.AbstractREST
{

XData UrlMap
{
<Routes>
	<!-- Send objects in this format: {"MDX":"QUERY"} HTTP method: POST -->

   <Route Url="/MDX" Method="POST" Call="WriteJSONfromMDX"/>
   <Route Url="/CancelQuery/:CubeKey/:QueryKey" Method="GET" Call="%DeepSee.ResultSet:%CancelQuery"/>
   <Route Url="/MDX2JSONP" Method="POST" Call="WriteJSONPfromMDX"/>
   <Route Url="/MDXDrillthrough" Method="POST" Call="WriteDrillthroughJSON" />
   <Route Url="/MDX2XMLA" Method="POST" Call="WriteXMLAfromMDX" />
   <Route Url="/KPI" Method="POST" Call="KPIExecute"/>

   <!-- Get info about availible filters and their values -->
   <Route Url="/Filters" Method="POST" Call="WriteFiltersForDataSource"/>

   <!-- Get info about widgets-->
   <Route Url="/Dashboards" Method="GET" Call="GetDashboardList"/>
   <Route Url="/Dashboards" Method="POST" Call="GetDashboardList" />
   <Route Url="/Dashboard" Method="POST" Call="GetDashboard" />
   <Route Url="/Widgets" Method="POST" Call="GetWidgetsList" />
   <Route Url="/Action/:Cube/:Action" Method="POST" Call="ExecuteAction"/>

   <!-- Send dashboard JSON -->
   <Route Url="/saveWidget" Method="POST" Call="saveWidget"/>
   <Route Url="/deleteWidget" Method="POST" Call="deleteWidget"/>

   <!-- Get info about system format and locale-->
   <Route Url="/Format" Method="GET" Call="GetFormat"/>

   <!-- Get info about pivot-->
   <Route Url="/DataSource" Method="POST" Call="GetDataSource" />
   <Route Url="/DataSourceList/:type" Method="POST" Call="GetListDataSources" />

   <!-- Get info about pivot-->
   <Route Url="/TermList" Method="POST" Call="GetTermList" />
   
   <!-- Get info about pivot variables-->
   <Route Url="/PivotVariables/:Cube" Method="GET" Call="WritePivotVariablesForCube"/>

   <!-- Get info about user config-->
   <Route Url="/Config" Method="POST" Call="SetConfig"/>
   <Route Url="/Config/:Application" Method="GET" Call="GetConfig" />

   <!-- Get info about user favorites-->
   <Route Url="/Favorites" Method="GET" Call="GetFavorites"/>
   <Route Url="/Favorites/:Item" Method="POST" Call="AddFavorite" />
   <Route Url="/Favorites/:Item" Method="DELETE" Call="RemoveFavorite" />

   <!-- Valid but illicit, do not use-->
   <Route Url="/MDX/:query" Method="GET" Call="WriteJSONfromMDXURL"/>
   <Route Url="/MDXfilters/:query" Method="GET" Call="WriteFiltersForMDX"/>
   

   <!-- Test methods-->
   <Route Url="/Test" Method="GET" Call="Test"/>
   <Route Url="/Logout" Method="GET" Call="Logout"/>
   
   <!-- DSW specific methods-->
   <Route Url="/Addons" Method="GET" Call="WriteAddons"/>
   <Route Url="/Themes" Method="GET" Call="WriteThemes"/>
 </Routes>
}

/// End user session by force.
/// Returns status.
ClassMethod Logout() As %Status
{
	#dim %session As %CSP.Session
	set st = %session.Logout(1)
	set %session.EndSession = 1
	return st
}

/// Test method, outputs <b>%request</b>, <b>%response</b> and <b>%session</b> objects. 
ClassMethod Test() As %Status
{
	set obj = ##class(%ZEN.proxyObject).%New()
	set obj.Status = "OK"
	set obj.Embed = $g(^MDX2JSON.Embed, $g(^%MDX2JSON.Embed, ""))
	set obj.User = $Username
	set obj.Version = "3.2.35"
	set obj.Parent = ##class(MDX2JSON.Tests).#LastCommit
	set obj.ParentTS = ##class(MDX2JSON.Tests).#LastCommitTS
	set obj.DefaultApp = $System.CSP.GetDefaultApp($Namespace)
	set obj.Mappings = ..GetMappings()
	if $$$Debug {
		set obj.Roles = $Roles
		set obj.Namespace = $Namespace
		set obj.Cache = $ZVersion
		set obj.SessionId = %session.SessionId
		set obj.Request = %request
		set obj.Response = %response
		//set obj.Session = %session
	}
	do obj.%ToJSON()
	return $$$OK
}

ClassMethod deleteWidget() As %Status
{
	set name = $$$R("key")
	set dashboardData = $$$R("Dashboard")
	
	return ##class(MDX2JSON.Utils).DeleteWidget(name,dashboardData)
}

ClassMethod saveWidget() As %Status
{
	set key = $$$R("key")
	set widgetData= $$$R("WidgetData")
	set dashboardData = $$$R("Dashboard")
	
	return ##class(MDX2JSON.Utils).AddWidget(widgetData,dashboardData,key)
}


/// Get all data sources including "pivot", "kpi", "worksheets","metrics"
ClassMethod GetListDataSources(Source) As %Status
{

	set Source = $ZCONVERT($ZCONVERT(Source ,"I","URL") ,"I","UTF8")

	if (Source = "pivot")
	{
		Set tSC = ##class(%DeepSee.Utils).%GetPivotListArray(.tParms,.pMetaData,.pData)
		
	}
	elseif (Source = "kpi")
	{
		Set tSC = ##class(%DeepSee.Utils).%GetKPIListArray(.tParms,.pMetaData,.pData)

	}
	elseif (Source = "worksheets")
	{
		Set tSC = ##class(%DeepSee.Utils).%GetWorksheetListArray(.tParms,.pMetaData,.pData)
		
	}
	elseif (Source = "metrics")
	{
		Set tSC = ##class(%DeepSee.Utils).%GetMetricListArray(.tParms,.pMetaData,.pData)
		
	}
	
	quit:$$$ISERR(tSC) tSC
	
	Set tSC = ##class(%DeepSee.REST.v1.DataServer).%CreateObjectFromArray(.pData,pMetaData,.tSourceObj)
	
	quit:$$$ISERR(tSC) tSC
	
	do tSourceObj.%ToJSON()
	
	quit tSC
}


ClassMethod GetDataSource() As %Status
{
	return ##class(MDX2JSON.Utils).GetDataSource($$$R("DataSource"))
}

ClassMethod GetTermList() As %Status
{
	return ##class(MDX2JSON.Utils).GetTermList($$$R("TermList"))
}

/// Wrapper for ##class(MDX2JSON.Utils).GetWidgetsList()<br>
/// Converts incoming request object (JSON: {Dashboard:"Dashboard Full Name"} and calls abovementioned method.
ClassMethod GetWidgetsList() As %Status
{
	return ##class(MDX2JSON.Utils).GetWidgetsList($$$R("Dashboard"))
}

/// Wrapper for ##class(MDX2JSON.Utils).GetDashboard()<br>
/// Converts incoming request object (JSON: {Dashboard:"Dashboard Full Name"} and calls abovementioned method.
ClassMethod GetDashboard() As %Status
{
	return ##class(MDX2JSON.Utils).GetDashboard($$$R("Dashboard"))
}

/// Returns JSON array of (title, path) for all dashboards in namespace (accessible to current user).
ClassMethod GetDashboardList() As %Status
{
	set st = $$$OK
	if %request.Method = "POST" {
		set folderName = $$$R("Folder")
	} else {
		set folderName = ##class(MDX2JSON.Dashboard).#folderName
	}

	try {
		do ##class(MDX2JSON.DashboardRS).WriteJSON(folderName)
	} catch ex {
		set st = ex.AsStatus()
	}
	return st
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteDrillthroughJSON(pMDX).<br>
/// Converts incoming request object and calls abovementioned method.
ClassMethod WriteDrillthroughJSON() As %Status
{
	return ##class(MDX2JSON.Utils).WriteDrillthroughJSON($$$R("MDX"))
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteJSONPfromMDX(pMDX)
/// Do not use.
ClassMethod WriteJSONfromMDXURL(MDX As %String) As %Status [ Internal ]
{
	set MDX = $ZCONVERT($ZCONVERT(MDX ,"I","URL") ,"I","UTF8")
  	set st = ##class(MDX2JSON.Utils).WriteJSONfromMDX(MDX)
  	return st
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteFiltersForMDX(pMDX)
/// Do not use.
ClassMethod WriteFiltersForMDX(MDX As %String) As %Status [ Internal ]
{
	set MDX = $ZCONVERT($ZCONVERT(MDX ,"I","URL") ,"I","UTF8")
	set st = ##class(MDX2JSON.Utils).WriteFiltersForMDX(MDX)
	return st
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteFiltersForDataSource(pDataSource, pValues, pSearchKey)
ClassMethod WriteFiltersForDataSource() As %Status
{
	set DataSource = $$$R("DataSource")
	set Values = $$$R("Values")
	set Search = $$$R("Search")
	
	#dim RequestedFilters As %ListOfDataTypes = $$$R("RequestedFilters")
	
	#dim RelatedFiltersList As %ListOfObjects = $$$R("RelatedFilters")
	if $IsObject(RelatedFiltersList) {
		for i=1:1:RelatedFiltersList.Count() {
			set RelatedFilter = RelatedFiltersList.GetAt(i)
			set RelatedFilters(RelatedFilter.Filter) = RelatedFilter.Value
		}
	}

   	set st = ##class(MDX2JSON.Utils).WriteFiltersForDataSource(DataSource, Values, Search, .RelatedFilters, RequestedFilters)
  	return st
}

///Execute requests from kpi
ClassMethod KPIExecute() As %Status
{
	try{
		set KPI = $$$R("KPI")
		set Drillthrough = $$$R("Drillthrough")
			

		if (Drillthrough = 1){
			set SortOrder = $$$R("SortOrder")
			set Filters = $$$R("Filters")
			set SortColumn = $$$R("SortColumn")
			set pSelection = SortColumn _ "," _ SortOrder

			set st = ##class(MDX2JSON.Utils).WriteDrillthroughJSONKPI(KPI, Filters, pSelection)
		}
		else {
			set st = ##class(%DeepSee.REST.v1.DataServer).WriteJSONfromKPI(KPI)
		}

	}catch ex {
		set st=ex.AsStatus()
	}

	return st
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteJSONPfromMDX(pMDX)<br>
/// Converts incoming request object and calls abovementioned method.
ClassMethod WriteJSONfromMDX() As %Status
{
	try {
		set mdx = $$$R("MDX")
		set timeout = $$$R("Timeout")
		set engine = $$$R("Engine")
		set cubeKey = $$$R("CubeKey")
		set queryKey = $$$R("QueryKey")
		
		if engine = "DeepSeeREST" {
			// DeepSeeREST engine for MDX->JSON transformation. Only in 15.3+
			set st = ##class(MDX2JSON.Utils).WriteJSONfromMDXNew(mdx)
		} else {
			// Default MDX2JSON engine. 14.1+
			if mdx'="" {
				set st = ##class(MDX2JSON.Utils).WriteJSONfromMDX(mdx, timeout)
			} else {
				set st = ##class(MDX2JSON.Utils).WriteJSONfromQuery(cubeKey, queryKey, timeout)				
			}
		}
	} catch ex {
		set st=ex.AsStatus()
	}

	return st
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteJSONPfromMDX(pMDX)<br>
/// Converts incoming request object and calls abovementioned method.
ClassMethod WriteJSONPfromMDX() As %Status
{
	return ##class(MDX2JSON.Utils).WriteJSONPfromMDX($$$R("MDX"))
}

/// Wrapper for ##class(MDX2JSON.Utils).WriteXMLAfromMDX(pMDX)<br>
/// Converts incoming request object and calls abovementioned method.
ClassMethod WriteXMLAfromMDX() As %Status
{
	return ##class(MDX2JSON.Utils).WriteXMLAfromMDX($$$R("MDX"))
}

/// Wrapper for ##class(MDX2JSON.Utils).GetFormat()
ClassMethod GetFormat() As %Status
{
	return ##class(MDX2JSON.Utils).GetFormat()
}

/// Wrapper for ##class(MDX2JSON.Users).GetConfig()
ClassMethod GetConfig(Application) As %Status
{
	w "{"_$$$ZENJSPAIR("Config",##class(MDX2JSON.Users).GetConfig(Application))_"}"
	return $$$OK
}

/// Wrapper for ##class(MDX2JSON.Users).SetConfig()
ClassMethod SetConfig() As %Status
{
	set config = $$$R("Config")
	if (($IsObject(config)) && (config.%IsA("%ZEN.proxyObject"))) {
		set config = ..OutputToStr(config,"%ToJSON")
	}
	return ##class(MDX2JSON.Users).SetConfig($$$R("Application"),config)
}

/// Get a list of favorites for a current user
ClassMethod GetFavorites() As %Status
{
	set st = ##class(MDX2JSON.Users).GetFavorites()
	return st
}

ClassMethod AddFavorite(Name As %String) As %Status
{
	set Name = $ZCONVERT($ZCONVERT(Name ,"I","URL") ,"I","UTF8")
	return ##class(%DeepSee.UserLibrary.Utils).%AddFavorite(Name)
}

ClassMethod RemoveFavorite(Name As %String) As %Status
{
	set Name = $ZCONVERT($ZCONVERT(Name ,"I","URL") ,"I","UTF8")
	return ##class(%DeepSee.UserLibrary.Utils).%RemoveFavorite(Name)
}

ClassMethod ExecuteAction(Cube As %String, Action As %String) As %Status
{
	set Cube = $ZCONVERT($ZCONVERT(Cube ,"I","URL") ,"I","UTF8")
	set Action = $ZCONVERT($ZCONVERT(Action ,"I","URL") ,"I","UTF8")
	return ##class(MDX2JSON.Utils).ExecuteAction(Cube,Action,%request.Content)
}

/// Return a list of available pivot variables for <var>Cupe</var>.
/// See correspontding method from DeepSee.REST.v1.InfoServer 
ClassMethod WritePivotVariablesForCube(Cube As %String) As %Status
{
	set Cube = $ZCONVERT($ZCONVERT(Cube,"I","URL") ,"I","UTF8")
	return ##class(MDX2JSON.Utils).WritePivotVariablesForCube(Cube)
}

/// DSW specific method, returns available addons
ClassMethod WriteAddons() As %Status
{
	#dim sc As %Status = $$$OK
	
	set app = "/dsw"
	set path = $system.CSP.GetFileName(app _ "/")
	set path = ##class(%File).NormalizeDirectory(path)
	set path = ##class(%File).SubDirectoryName(path, "addons", $$$YES)	
	set url = app _ "/addons/"
	
	#dim rs As %SQL.ClassQueryResultSet = ##class(%File).FileSetFunc(path, "*.js")
	
	set list = $$$NewDynDTList
	while rs.%Next() {
		$$$Insert(list, url _ rs.ItemName)
	}
	set sc = ##class(MDX2JSON.Utils).CreateAddons(list)
	
	if $$$ISOK(sc) {
		$$$ListToJSON(list)
	}
    quit sc
}

/// DSW specific method, returns available themes
ClassMethod WriteThemes() As %Status
{
	#dim sc As %Status = $$$OK
	
	set app = "/dsw"
	set path = $system.CSP.GetFileName(app _ "/")
	set path = ##class(%File).NormalizeDirectory(path)
	set path = ##class(%File).SubDirectoryName(path, "themes", $$$YES)	
	set url = app _ "/themes/"
	
	#dim rs As %SQL.ClassQueryResultSet = ##class(%File).FileSetFunc(path, "*.css")
	
	set list = $$$NewDynDTList
	while rs.%Next() {
		$$$Insert(list, url _ rs.ItemName)
	}
	$$$ListToJSON(list)
	
    quit sc
}

ClassMethod WriteJSONfromKPI() As %Status [ CodeMode = objectgenerator ]
{
	set class = "%DeepSee.REST.v1.DataServer"
	set codeFind  = "Set tKpiSC"
	set base = ##class(%Dictionary.MethodDefinition).IDKEYOpen(class, "WriteJSONfromKPI").Implementation.Read($$$MaxStringLength)
	set base = $replace(base, codeFind, "Set:'$LF(tKpiPropList, ""%series"") tKpiPropList = tKpiPropList _ $LB(""%series"")" _ $c(13, 10, 9, 9) _ codeFind)
	set base = $replace(base, "..", "##class(" _class _ ").")
	do %code.Write(base)
}

}
