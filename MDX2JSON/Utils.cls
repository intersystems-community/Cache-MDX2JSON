Include MDX2JSON.MDX2JSON

/// Utility class, wrappers for processing of MDX queries in <b>MDX2JSON.ResultSet</b>.
/// Outputs JSON, JSONP and XML/A.<br>
/// Also has functionality for getting information about cubes, dashboards and widgets.
Class MDX2JSON.Utils
{

/// Transforms MDX query into executed <b>MDX2JSON.ResultSet</b>.<br>
/// <b>MDX</b> - String containing MDX query.<br>
/// <b>Status</b> - Status of query execution.<br>
ClassMethod GetResultSet(MDX As %String, Output Status) As MDX2JSON.ResultSet
{
	set Status = $$$OK
	set RS = ##class(MDX2JSON.ResultSet).%New()
	set Status = RS.%PrepareMDX(MDX)
	return RS
}

/// Transforms MDX query into executed <b>MDX2JSON.ResultSet</b>.<br>
/// <b>MDX</b> - String containing MDX query.<br>
/// <b>Status</b> - Status of query execution.<br>
ClassMethod GetResultSetFromQuery(CubeKey As %String, QueryKey As %String, Output Status) As MDX2JSON.ResultSet
{
	set Status = $$$OK
	set RS = ##class(MDX2JSON.ResultSet).%New()
	set Status = RS.%PrepareKey(CubeKey, QueryKey)
	return:$$$ISERR(Status) RS
	
	do:$$$ISOK(Status) RS.%GetQueryText()
	return RS
}

ClassMethod ExecuteResultSet(RS As MDX2JSON.ResultSet, QueryKey As %String = "", Timeout As %Integer = 0) As %Status
{
	set Params = ""
	set Status = $$$OK
	
	if ((Timeout = 0) || (Timeout = "")) {
		set Status = RS.%ExecuteAsynch(QueryKey ,.Params, $$$YES)
	} else {
		set Status = RS.%ExecuteAsynch(QueryKey ,.Params, $$$NO)
		set TimeElapsed = 0
		set QueryStatus = 0
		while (TimeElapsed < Timeout)&&(QueryStatus<100)&&($$$ISOK(Status)) {
			hang .01
			set TimeElapsed = TimeElapsed + .01		
			// Check query status again
			set QueryStatus = RS.%GetStatus(,.Status)
		}
	}
	
	quit Status
}

/// Automatic processing of MDX query and outputting resulting JSON.<br>
/// <b>MDX</b> - String containing MDX query.<br>
ClassMethod WriteJSONfromMDX(MDX As %String, Timeout As %Integer = 0) As %Status
{
	#dim RS As MDX2JSON.ResultSet
	set RS = ..GetResultSet(MDX, .st)
	return:$$$ISERR(st) st
	
	set st = ..ExecuteResultSet(RS, , Timeout)
	return:$$$ISERR(st) st
		
	set obj = RS.ToProxyObject(.st)
	return:$$$ISERR(st) st
	$$$DynObjToJSON(obj)
	
	return $$$OK
}

/// Automatic processing of MDX query and outputting resulting JSON.<br>
/// <b>MDX</b> - String containing MDX query.<br>
ClassMethod WriteJSONfromQuery(CubeKey As %String, QueryKey As %String, Timeout As %Integer = 0) As %Status
{
	#dim RS As MDX2JSON.ResultSet
	set RS = ..GetResultSetFromQuery(CubeKey, QueryKey, .st)
	return:$$$ISERR(st) st

	set st = ..ExecuteResultSet(RS, , Timeout)
	return:$$$ISERR(st) st
		
	set obj = RS.ToProxyObject(.st)
	return:$$$ISERR(st) st
	$$$DynObjToJSON(obj)
	
	return $$$OK
}

/// Automatic processing of MDX query and outputting resulting JSONP.<br>
/// <b>pMDX</b> - String containing MDX query.<br>
ClassMethod WriteJSONPfromMDX(pMDX As %String) As %Status
{
	set RS = ..GetResultSet(pMDX,.st)
	return:$$$ISERR(st) st
	set st = ..ExecuteResultSet(RS)
	return:$$$ISERR(st) st
	
	set PageSize = 1000
	set CurrPage = 1
	set st = RS.%OutputJSON(PageSize,CurrPage,,PageSize)
	return st
}

/// Automatic processing of MDX query and outputting resulting JSON.<br>
/// <b>pMDX</b> - String containing MDX query.<br>
ClassMethod WriteJSONfromMDXNew(pMDX As %String) As %Status
{
	#if $$$comClassDefined("%ZEN.Auxiliary.jsonMDXProvider")
		set Provider = ##class(%ZEN.Auxiliary.jsonMDXProvider).%New()
		set Provider.mdxQuery = pMDX
		set st = Provider.%DrawJSON()
	#else
		set st = $$$ERROR($$$GeneralError,"Class %ZEN.Auxiliary.jsonMDXProvider does not exist")
	#endif
	return st
}

/// Automatic processing of MDX Drillthrough query and outputting resulting listing as JSON.<br>
/// <b>pMDX</b> - String containing MDX Drillthrough query.<br>
ClassMethod WriteDrillthroughJSON(pMDX As %String) As %Status
{
	set RS = ..GetResultSet(pMDX,.st)
	return:$$$ISERR(st) st
	set st = ..ExecuteResultSet(RS)
	return:$$$ISERR(st) st
	
	set SQL = RS.%GetListingSQL()
	do ##class(%ZEN.Auxiliary.altJSONSQLProvider).%WriteJSONFromSQL(,SQL,,$$$MaxCacheInt)

	return $$$OK
}

ClassMethod TestSQL(ByRef tSQL As %String) [ Language = python ]
{
	import iris
	pSQL = tSQL.upper()

	forbiden_lines = ["DROP", "DELETE", "TRUNCATE", "ALTER", "GRANT", "REVOKE", "CREATE"]

	# check if any of the forbiden_lines contains in pSQL
	for words in forbiden_lines:
		if pSQL.find(words) > 0:
			pSQL = "" # return empty line if any
			break

	
	return pSQL
}

ClassMethod WriteDrillthroughJSONKPI(pSQL As %String) As %Status
{

	set tSQL = ..TestSQL(pSQL)
	
	Set statement = ##class(%SQL.Statement).%New()

	// Prepare the SQL query
	Set status = statement.%Prepare(tSQL)

	// Check for errors
	If $$$ISERR(status) {
		Write "Error preparing SQL statement or query is forbidden: ", $System.Status.GetErrorText(status), !
		Quit
	}
	
	else{
		
		do ##class(%ZEN.Auxiliary.altJSONSQLProvider).%WriteJSONFromSQL(,tSQL,,$$$MaxCacheInt) // receiving sql and process it 
	}
	
	
	return $$$OK
}


/// Automatic processing of MDX query and outputting resulting XML/A.<br>
/// <b>pMDX</b> - String containing MDX query.<br>
ClassMethod WriteXMLAfromMDX(pMDX As %String) As %Status
{
	set RS = ..GetResultSet(pMDX,.st)
	return:$$$ISERR(st) st
	set st = ..ExecuteResultSet(RS)
	return:$$$ISERR(st) st
	
	set st = RS.%OutputXMLA()

	return st
}

ClassMethod WriteDrillthroughJSONKPI(pSQL As %String) As %Status
{
	do ##class(%ZEN.Auxiliary.altJSONSQLProvider).%WriteJSONFromSQL(,pSQL,,$$$MaxCacheInt) // receiving sql from kpi and process it 
	return $$$OK
}

/// Gets filters for MDX expression.<br>
/// <b>pMDX</b> - String containing MDX query.<br>
ClassMethod WriteFiltersForMDX(pMDX As %String) As %Status
{
	set RS = ..GetResultSet(pMDX,.st)
	return:$$$ISERR(st) st
	set st = ..ExecuteResultSet(RS)
	return:$$$ISERR(st) st
	
	set st=RS.%GetFiltersForCellRange(.filters,0,0,RS.%GetAxisSize(2),RS.%GetAxisSize(1),.measure)

	return st
}

/// Get all filters for DeepSee DataSource in JSON format.<br>
/// <b>pDataSource</b> - name of DeepSee datasource (cube, pivot, kpi, metric).<br>
/// <b>pValues</b> - write all filters' values. Takes time.
ClassMethod WriteFiltersForDataSource(pDataSource As %String, pValues As %Boolean = 0, pSearchKey As %String = "", ByRef pRelatedFilters, pRequestedFilters As %ListOfDataTypes) As %Status
{
	set st = ##class(%DeepSee.Dashboard.Utils).%GetFiltersForDataSource(pDataSource, .tFilters)
	return:$$$ISERR(st) st
	return:($d(tFilters)=0) $$$ERROR($$$GeneralError,"Empty Filter values array. DataSource does not exist?")

	if $isobject($g(pRequestedFilters)) {
		set key = $order(tFilters(""))		
		for {
			quit:key=""
			kill:'pRequestedFilters.Find($lg(tFilters(key),2)) tFilters(key)
			set key = $order(tFilters(key))
	   	}
	}

	if (pValues=1) {
		set key = $order(tFilters(""))
		while (key '= "") {
			set st = ##class(%DeepSee.Dashboard.Utils).%GetMembersForFilter(pDataSource,$lg(tFilters(key),2),.tMembers,.tDefaultFilterValue,pSearchKey,.pRelatedFilters,0,,.tValueList)
			return:$$$ISERR(st) st
			if +$g(tMembers) set tMembers = $g(tFilters(key)) // check if list contain simple number and replace it with proper query
			merge tFilters(key) = tMembers // merge filter values
			set key = $order(tFilters(key))
	   	}
	}
   	

   	Set st = ##class(%ZEN.Auxiliary.altJSONProvider).%ArrayToJSON($lb("name", "path", "info"),.tFilters)
	return st
}

/// Get information about pivot. <br>
/// <b>pDataSource</b> - pivot fullName.
ClassMethod GetDataSource(pDataSource As %String)
{
	
	set st = $$$OK
	try {
		
		if ($FIND(pDataSource, ".pivot") = ($LENGTH(pDataSource) + 1)) {
			set st = ..OpenPivotByName(pDataSource, .dataSource)
			return:($$$ISERR(st)) st
			
			if (dataSource.mdx="") {
				set st = ##class(MDX2JSON.Dashboard).GetMdx(pDataSource, .mdx, .basemdx)
				return:($$$ISERR(st)) st
				set dataSource.mdx = mdx
			}
			set st = ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON(dataSource, .out)
			
		}
		
	} catch ex {
		set st = ex.AsStatus()
		do ex.Log() // logs error info to System Error log
	}
	
	return st
}

/// Opens DeepSee pivot by it's name. Returns status of atempt to locate and open pivot.
/// <b>PivotName</b> - fullName property of %DeepSee.Dashboard.Pivotn class.<br>
/// <b>Pivot</b> - OREF to opened dashboard would be passed here upon successfull execution.
ClassMethod OpenPivotByName(PivotName As %Integer, Output Pivot As %DeepSee.Dashboard.Pivot) As %Status
{
	 kill Pivot
	 
	 set id = ""
	 set global = ##class(MDX2JSON.DashboardRS).#global
	 set pivotclass = "%DeepSee.Dashboard.Pivot"
	 for {
	 	set id = $order(@global@(id))
	 	quit:id=""
	 		
	 	/// first we check that it's a pivot (not a dashboard, etc.)
		set oid = ##class(%DeepSee.UserLibrary.FolderItem).%ComposeOid(id)
	    do ##class(%DeepSee.UserLibrary.FolderItem).%OnDetermineClass(oid, .class)
	    CONTINUE:class'=pivotclass
	    
	    /// second we check that it's the one we need
	    quit:..GetPivotFullName(id)=PivotName
	 }
	 return:id="" $$$ERROR($$$GeneralError,"Pivot " _ PivotName _ " does not exist")
	 set Pivot = ##class(%DeepSee.Dashboard.Pivot).%OpenId(id,,.st)
	 return st
}

/// Get Pivot full name by id
ClassMethod GetPivotFullName(id As %String)
{
	set folder = ##class(%DeepSee.UserLibrary.FolderItem).folderGetStored(id)
    set name = ##class(%DeepSee.UserLibrary.FolderItem).nameGetStored(id)
    return ##class(%DeepSee.Dashboard.Pivot).fullNameCompute(id, folder, name)
}

/// Get information about TermList. <br>
/// <b>pTermList</b> - TermList full name (eg.: Patients Pivots) without .termlist extension.
ClassMethod GetTermList(pTermList As %String)
{
	set st = $$$OK
	try {
		do ##class(%DeepSee.TermList).%GetValueArray(pTermList,.pArray)
		set obj = ##class(%ZEN.proxyObject).%New()
		m obj.%data = pArray
		set st = obj.%ToJSON()
	} catch ex {
		set st = ex.AsStatus()
	}
	return st
}

/// Using dashboard name get JSON representation (array of ("type","title","mdx")) of all its' widgets.<br>
/// <b>pDashName</b> - fullname of dashboard. Eg: "KPIs & Plugins/KPI with Listing.dashboard". Case insensitive.
ClassMethod GetWidgetsList(pDashName As %String) As %Status
{
	try {
		set st = ##class(MDX2JSON.Dashboard).OpenDashboardByName(pDashName, .dash)
		return:($$$ISERR(st)) st
		
		set canaaccess = dash.%CheckResource()
		return:canaaccess=0 $$$ERROR($$$GeneralError,"Access denied to " _ pDashName)
		
		set st = ##class(MDX2JSON.Dashboard).WidgetsToProxyObject(dash, .widgetlist)
		return:($$$ISERR(st)) st
		w "" // weird hack required for 15.3
		$$$DynObjToJSON(widgetlist)
	} catch ex {
		set st = ex.AsStatus()
		do ex.Log()
	}
	return st
}

/// Using dashboard name get JSON representation of all its' widgets and filters.<br>
/// <b>pDashName</b> - fullname of dashboard. Eg: "KPIs & Plugins/KPI with Listing.dashboard". Case insensitive.
ClassMethod GetDashboard(pDashName As %String) As %Status
{
	try {
		set st = ##class(MDX2JSON.DashboardFilters).OpenDashboardByName(pDashName, .dash)
		return:($$$ISERR(st)) st
		
		set st = ##class(MDX2JSON.DashboardFilters).WidgetsToProxyObject(dash, .widgetlist)
		return:($$$ISERR(st)) st
		w "" // weird hack required for 15.3
		$$$DynObjToJSON(widgetlist)
	} catch ex {
		set st = ex.AsStatus()
		do ex.Log()
	}
	return st
}

/// Get format defaults.
ClassMethod GetFormat() As %Status
{
	set st = $$$OK
	set datelist="DD Mmm [YY]YY^MM/DD/[YY]^DD Mmm [YY]YY^YYYY-MM-DD^DD/MM/[YY]YY^Mmm D, YYYY^Mmm D YYYY^Mmm DD [YY]YY^YYYYMMDD^Mmmmmm D, YYYY^W^Www^Wwwwww^[D]D/[M]M/YYYY^nnn"	
	set timelist="hh:mm:ss,hh:mm,hh:mm:ss[AM/PM],hh:mm[AM/PM]" // lists taken from %CSP.UI.Portal.NLSEdit - DrawProperties
	set proplist = "AM,DateSeparator,DecimalSeparator,MinusSign,MonthAbbr,MonthName,NumericGroupSeparator,NumericGroupSize,PM,PlusSign,TimePrecision,TimeSeparator,WeekdayAbbr,WeekdayName"
	set obj = ##class(%ZEN.proxyObject).%New()
	
	try {
		for i = 1:1:$L(proplist, ",") {
			set property = $P(proplist, ",", i)
			do obj.%DispatchSetProperty(property,##class(%SYS.NLS.Format).GetFormatItem(property))
		}
		
		// that's why we cant just do ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON()
		set obj.DateFormat = $P(datelist, "^",##class(%SYS.NLS.Format).GetFormatItem("DateFormat"))
		set obj.TimeFormat = $P(timelist, ",",##class(%SYS.NLS.Format).GetFormatItem("TimeFormat"))
		
		do obj.%ToJSON()
	} catch ex {
		set st = ex.AsStatus()
	}
	return st
}

ClassMethod ExecuteAction(Cube As %String, Action As %String, Context As %ZEN.proxyObject = {##class(%ZEN.proxyObject).%New()}) As %Status
{
	set st = $$$OK
	set Cube = $$$UPPER(Cube)
	set:$FIND(Cube, ".KPI") Cube = $TRANSLATE(Cube, ".KPI", "") // cut off extension ".kpi" from Cube name if there any 
	set ActionClass = $G($$$DeepSeeMetaGLVN("cubes",Cube,"actionClass"), $G($$$DeepSeeMetaGLVN("kpis",Cube)))
	if (ActionClass'="") {
		set st = $classmethod(ActionClass,"%OnDashboardAction",Action,Context)
	}
	return st
}

/// Return a list of available pivot variables for <var>Cupe</var>.
/// See correspontding method from DeepSee.REST.v1.InfoServer 
ClassMethod WritePivotVariablesForCube(Cube As %String) As %Status
{
	set st = $$$OK
	try {
		quit:'##class(%DeepSee.Utils).%CubeExists(Cube, .st) 
		
		set st = ##class(%DeepSee.Utils).%GetPivotVariables(Cube, .vars)
		
		if $$$ISOK(st)&&('$data(vars)) {
			set st = $$$ERROR($$$GeneralError,$$$FormatText("No pivot variables available for %1", Cube))
		}
		quit:$$$ISERR(st)
		
		set st = ##class(%ZEN.Auxiliary.jsonProvider).%ArrayToJSON($lb("name", "caption", "defValue", "context", "desc"),.vars)
	}
	catch ex {
		set st = ex.AsStatus()
	}
	
	quit st
}

ClassMethod CreateAddons(Addons As %ListOfDataTypes) As %Status
{
	#dim sc,sc1 As %Status = $$$OK
	set base = "DSW.Addons."
	for i=1:1:$$$ListSize(Addons) {
		set file = $$$ListGet(Addons, i)
		set file = ##class(%File).GetFilename(file)
		set addon = $p(file, ".", 1, *-1) // remove extension
		
		set class = base _ addon
		
		set sc1 = ##class(%Dictionary.CacheClassname).IsValid(class)
		if $$$ISERR(sc1) {
			set sc = $$$ADDSC(sc, sc1)
			CONTINUE
		}
		
		if $$$comClassDefined(class) {
			// compiled class exists - we're set 
		} elseif $$$defClassDefined(class) {
			// class exists but uncompiled - add to compile local
			set classes(class) = ""
		} else {
			// class does not exist
			// create and add to compile local
			set sc1 = ..CreateAddonClass(class)
			set sc = $$$ADDSC(sc, sc1)
			set:$$$ISOK(sc1) classes(class) = "" 
		}	
	}
	
	// compile classes if we have any
	if $d(classes)=10 {
		set sc1 = $system.OBJ.Compile(.classes, "cuks /checkuptodate=expandedonly /displaylog=0 /displayerror=0")
		set sc = $$$ADDSC(sc, sc1)
	}
	quit sc
}

/// Create class for an addon
/// w ##class(MDX2JSON.Utils).CreateAddonClass("DSW.Addon.A")
ClassMethod CreateAddonClass(Class As %Dictionary.CacheClassname) As %Status
{
	quit:$$$defClassDefined(Class) $$$OK
	
	set classObj = ##class(%Dictionary.ClassDefinition).%New(Class)
	set classObj.Super = "%DeepSee.Component.Portlet.abstractPortlet"
	set classObj.GeneratedBy = "MDX2JSON and DeepSeeWeb"
	set classObj.Description = "Portlet for MDX2JSON and DeepSeeWeb. Autogenerated. Do not edit."
	
	set propertyObj = ##class(%Dictionary.PropertyDefinition).%New(Class _ ":Data")
	set propertyObj.Type = "%String"
	do classObj.Properties.Insert(propertyObj)
	
	set parameterOnj = ##class(%Dictionary.ParameterDefinition).%New(Class _ ":USECOMMONDIRECTORY")
	set parameterOnj.Default = 1
	do classObj.Parameters.Insert(parameterOnj)
	
	set methodObj = ##class(%Dictionary.MethodDefinition).%New(Class _ ":%OnGetPortletSettings")
	set methodObj.ClassMethod = $$$YES
	set methodObj.FormalSpec = "*pInfo:%List,&pSettings"
	set methodObj.ReturnType = "%Status"
	do methodObj.Implementation.Write(	$c(9) _ "Kill pInfo" _ $$$NL _ 
										$c(9) _ "Set pInfo = 1" _ $$$NL _ 
										$c(9) _ "Set pInfo(1) = $lb(""Data"", , , ""Data"", ""Data setting"")" _ $$$NL _ 
										$c(9) _ "Quit $$$OK")

	do classObj.Methods.Insert(methodObj)
	
	quit classObj.%Save()
}

}
