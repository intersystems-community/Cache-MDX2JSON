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

ClassMethod QuerySet(MDX) As %Status
{
	set ^Query($I(^Query), "%dsQuery") = MDX
}

/// Automatic processing of MDX query and outputting resulting JSON.<br>
/// <b>MDX</b> - String containing MDX query.<br>
ClassMethod WriteJSONfromMDX(MDX As %String, Timeout As %Integer = 0) As %Status
{
	Set tSC = $$$OK
	#dim RS As MDX2JSON.ResultSet

	set RS = ..GetResultSet(MDX, .tSC)
	set cube = ##class(%DeepSee.Utils).%IsCubeCompound(RS.%Cube) // check if cube is compound type
	return:$$$ISERR(tSC) tSC

	if cube // if cube is compound then we prepare it using %ZEN.Auxiliary.jsonMDXProvider 
	{
		Set tProvider = ##class(%ZEN.Auxiliary.jsonMDXProvider).%New()
		Set tProvider.mdxQuery = MDX
		Set tWait = %session.AppTimeout - $S(%session.AppTimeout>2:2,1:0)	// Send something back jst before the appTimeout is reached	
                Set tSC = ##class(%DeepSee.REST.v1.DataServer).%WaitForProviderResults(tProvider,tWait)
	
		set tSC = ..ExecuteResultSet(RS, ,Timeout)
		return:$$$ISERR(tSC) tSC
		
		set obj = RS.ToProxyObject(.tSC)
		return:$$$ISERR(tSC) tSC

		set %dsQuery = MDX

		// initiate an RS object to a global variable %dsResultSet
		set %dsResultSet = RS

		set %dsCubeName = RS.%Cube

		// check if audit global hold something and execute it
		try {xecute ^DeepSee.AuditQueryCode} catch {}

		$$$DynObjToJSON(obj)
	
	}else{ // if cube is not compound execute the query in usual way

		set tSC = ..ExecuteResultSet(RS, ,Timeout)
		return:$$$ISERR(tSC) tSC
		
		set obj = RS.ToProxyObject(.tSC)
		return:$$$ISERR(tSC) tSC

		set %dsQuery = MDX
		set %dsResultSet = RS

		// check if audit global hold something and execute it
		try {xecute ^DeepSee.AuditQueryCode} catch {}

		$$$DynObjToJSON(obj)
	}


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

/// Execute SQL query taken from KPI and extract column values by name of column
/// Output array with list of values like so pValue(n) = $LB(sNameList(i)...)
ClassMethod GetSQLValues(pSQL, Output pValues As %String, Output tResultSet As %SQL.Statement) As %Status
{

	set st = $$$OK
	Set tResultSet = ##class(%SQL.Statement).%ExecDirect(,pSQL)
		set tCount = 0
		
		while tResultSet.%Next()
		{
				set lValue = ""
				for i=1:1:tResultSet.%GetMetadata().columnCount
				{	
					set sNameList(i) = tResultSet.%GetMetadata().columns.GetAt(i).label 
					set lValue = lValue _ $lb(tResultSet.%Get(sNameList(i))) // append next column to the list
				}

			Set tCount = tCount + 1
			set pValues(tCount) = lValue 
		}	
	return st
}

/// This method provides listing execution for KPI. 
/// <b>tKPI<b> as a name of KPI class. <b>pFilters<b> not yet implemented 
/// as a <b>pSelection<b>. Thats for future use. 
ClassMethod WriteDrillthroughJSONKPI(tKPI As %String, pFilters As %String, pSelection As %String) As %Status
{

	Set st = $$$OK
	
	Set tKpiClassName = ##class(%DeepSee.Utils).%GetKPIClass(tKPI,.tSC) // get name of a kpi from REST
	set kpitype = $classmethod(tKpiClassName, "%GetSourceType")
	
	if (kpitype="sql") {
		set pSQL = $classmethod(tKpiClassName,"%OnGetListingSQL",pFilters,pSelection) // invoke corresponding method from given kpi and get sql query
		set values = ..GetSQLValues(pSQL, .pValue, .tResultSet)

		for i=1:1:tResultSet.%GetMetadata().columnCount
		{	
			set pList(i) = tResultSet.%GetMetadata().columns.GetAt(i).label 
			set pList(i, "columnNo") = i
			Set tKpiPropIdx = $O(pList(""),1,tProperty)
			Set tKpiPropList = ""
			While (tKpiPropIdx'="") {
				Set tKpiPropList = tKpiPropList _ $LB(tProperty)
				Set tKpiPropArray(tKpiPropIdx) = $LB(tProperty,$G(pList(tKpiPropIdx,"name")),$G(pList(tKpiPropIdx,"columnNo")))
				Set tKpiPropIdx = $O(pList(tKpiPropIdx),1,tProperty)
				
		}

		}
			Set tKpiSC = $classmethod(tKpiClassName,"%GetKPIValueArray",tKpiClassName,,.tKpiPropList,.tFilters)

			Set tSC = ##class(%DeepSee.REST.v1.DataServer).%CreateObjectFromArray(.pValue,tKpiPropList,.tValueObj)		
			If $$$ISERR(tSC) Quit

			Set tSC = ##class(%DeepSee.REST.v1.DataServer).%CreateObjectFromArray(.tKpiPropArray,$LB("name","caption","columnNo"),.tPropObj)
    		If $$$ISERR(tSC)

			// Use consistent objects for normalized return
			Set tProvider = ##class(%ZEN.Auxiliary.jsonMDXProvider).%New()
			Set tInfoObj = tProvider.%ConstructNewDynamicObject()
			Set tResultObj = tProvider.%ConstructNewDynamicObject()
			
			Set:$IsObject(tPropObj.children) tResultObj.Properties = tPropObj.children
			Set:$IsObject(tValueObj.children) tResultObj.Series = tValueObj.children
		
			Set tInfoObj.Error = tProvider.%StatusToDynamicObject(tKpiSC)
			Set tInfoObj.KpiName = tKpiClassName
			
			Set tKpiObj = tProvider.%ConstructNewDynamicObject()
			Set tKpiObj.Info = tInfoObj
			Set tKpiObj.Result = tResultObj

			Set tSC = tProvider.%ObjectToJSON(tKpiObj)

		}else{
		
			quit $$$ERROR($$$GeneralError, "KPI type " _ kpitype _ " not supported")
	}
	
	return st
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

		if ($FIND(pDataSource, ".pivot") = ($LENGTH(pDataSource) + 1) && pDataSource '="") {
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
		
		set %dsDashboard = pDashName
		
		// check if audit global hold something and execute it
		try {xecute ^DeepSee.AuditCode} catch {}

		$$$DynObjToJSON(widgetlist)
	} catch ex {
		set st = ex.AsStatus()
		do ex.Log()
	}
	return st
}

/// the method initiate the audit for %dsDashboard
ClassMethod SetAuditCode() As %Status
{
	set ^DeepSee.AuditCode = "Do ##class(MDX2JSON.Utils).SetAuditDash()"

	quit $$$OK
}

/// the method initiate the audit for %dsQueryText, %dsCubeName, %dsResultSet
ClassMethod SetAuditQueryCode() As %Status
{
	set ^DeepSee.AuditQueryCode = "Do ##class(MDX2JSON.Utils).SetAuditQuery()"

	quit $$$OK
}

/// zw ^AuditLogDash to get the dashboard audit dashboard readings
ClassMethod SetAuditDash() As %Status
{
	set ^AuditLogDash($INCREMENT(^AuditLogDash),"%dsDashoard") = %dsDashboard

	quit $$$OK
}

/// zw ^AuditLogQuery to get the query audit readings 
/// zw ^AuditLogCube to get the cube audit readings
/// zw ^AuditLogRS to get the RS audit readings
ClassMethod SetAuditQuery() As %Status
{
	set ^AuditLogQuery($INCREMENT(^AuditLogQuery),"%dsQueryText") = %dsQueryText
	set ^AuditLogCube($INCREMENT(^AuditLogQuery),"%dsCubeName") = %dsCubeName
	set ^AuditLogRS($INCREMENT(^AuditLogRS),"%dsResultSet") = %dsResultSet

	quit $$$OK
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

/// Add new widgets and edit existing ones directly from DeepSeeWeb
/// it takes widget name(key) as unique identifier as string, dashboard name as string
/// and object with parameters as zen.proxyObject
ClassMethod AddWidget(sWidget As %String, sDashboard As %String, key As %String) As %Status
{
	set st = $$$OK
	set dExist=##class(%DeepSee.Dashboard.Utils).%DashboardExists(sDashboard) 

	// Check if dashboard exists
	If (dExist '= 1) 
	{
		Quit $$$ERROR($$$GeneralError,"Dashboard " _ sDashboard _ " does not exists")
	}
	Set tDash=##class(%DeepSee.Dashboard.Utils).%OpenDashboard(sDashboard, .st)
	
	// Check if widget with name is exists
	set isExists = 0 
	for i=1:1:tDash.widgets.Count()
	{
		if (tDash.widgets.GetAt(i).name = sWidget.name)
		{	
			set isExists = 1
		}
	}

	// Adding new widget
	if ($LENGTH(key) = 0) { // if key received empty then we expect new widget if not then else logic is working
		// Check if we trying to create widget with exists name
		if (isExists = 1) {
			return $$$ERROR($$$GeneralError,"Widget " _ sWidget.name _ " already exists")
		}

		set tWidgets = ##class(%DeepSee.Dashboard.Widget).%New()
		set st = ..UpdateWidget(tWidgets, sWidget)

		if (st = $$$OK) // checking for errors in UpdateWidget
		{
			$$$Insert(tDash.widgets, tWidgets)
			do tDash.%Save()
		}

	} else {		
		// Edit exists widget				
		for i=1:1:tDash.widgets.Count()
		{

			set dWidgets = tDash.widgets.GetAt(i)

			// Check if we trying to change widget name with exists one
			if ((dWidgets.name '= key) && (dWidgets.name = sWidget.name)) {
				return $$$ERROR($$$GeneralError,"Widget " _ sWidget.name _ " already exists")

			}

			if (dWidgets.name = key)
			{
				set changed = dWidgets
			}
		}
		if (changed '= "") {
			set st = ..UpdateWidget(changed, sWidget)
			if (st = $$$OK) // checking for errors in UpdateWidget
			{
				do tDash.%Save()	
			}	
		}
	}		
		
	return st
}

/// This method remove widget from dashboard directly from DeepSeeWeb
/// it takes widget name as unique identifier and dashboard name 
ClassMethod DeleteWidget(wName As %String, sDashboard As %String) As %Status
{
	set st = $$$OK

	set dExist=##class(%DeepSee.Dashboard.Utils).%DashboardExists(sDashboard) 

	// Check if dashboard exists
	If (dExist '= 1) 
	{
		Quit $$$ERROR($$$GeneralError,"Dashboard " _ sDashboard _ " does not exists")
	}
	Set tDash=##class(%DeepSee.Dashboard.Utils).%OpenDashboard(sDashboard, .st)

	// Check if widget with name is exists
	set isExists = 0 
	for i=1:1:tDash.widgets.Count()
	{
		if (tDash.widgets.GetAt(i).name = wName)
		{	
			set isExists = 1
		}
	}

	if (isExists = 1)
	{
		for i=1:1:tDash.widgets.Count()
		{
			if (tDash.widgets.GetAt(i).name = wName) 
			{
				do tDash.widgets.RemoveAt(i)
				do tDash.%Save()
			}
		}
	}else
	{
		quit $$$ERROR($$$GeneralError,"Widget " _ wName _ " is not exists")

	}

	return st
}

/// the collection of necessary parameters for building widget 
ClassMethod UpdateWidget(widgetToUpdate As %DeepSee.Dashboard.Widget, data As %ZEN.proxyObject) As %Status
{
	set st = $$$OK

	set widgetToUpdate.name = data.name
	set widgetToUpdate.title = data.title
	if (data.dataSource = "")
	{
		quit $$$ERROR($$$GeneralError,"Parameter DataSource is not set")
	}else
	{
		set widgetToUpdate.dataSource = data.dataSource
	}
	
	set widgetToUpdate.dataLink = data.dataLink
	
	if (data.type = "pivot") 
	{
		set widgetToUpdate.type = "pivot"
		set widgetToUpdate.subtype = "pivot"
	}
	elseif (data.type '= "pivot")
	{
		set widgetToUpdate.type = "pivot"
		set widgetToUpdate.subtype = data.type
	}

	if (data.displayInfo '= "") {
	  set widgetToUpdate.top = data.displayInfo.top
	  set widgetToUpdate.left = data.displayInfo.left
	  set widgetToUpdate.width = data.displayInfo.width
	  set widgetToUpdate.height = data.displayInfo.height
	  set widgetToUpdate.homeColL = data.displayInfo.topCol
	  set widgetToUpdate.homeRowL = data.displayInfo.leftRow
	  set widgetToUpdate.colSpanL = data.displayInfo.colWidth
	  set widgetToUpdate.rowSpanL = data.displayInfo.rowHeight
	 }

	return st
}

}
