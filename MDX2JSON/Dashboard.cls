Include MDX2JSON.MDX2JSON

/// Class with methods related to DeepSee Dashboard and Widget processing.
Class MDX2JSON.Dashboard
{

/// Folder, from which we get Dashboards.
Parameter folderName As %String = "Mobile";

/// Get SQL for folder, from which we get Dashboards. 
ClassMethod GetDashboardListSQL(folderName As %String = {..#folderName}) As %String
{
	set basesql = "SELECT MDX2JSON.ResolveText(title) AS title, fullName AS path, MDX2JSON.GetDashCover(bookCover) AS Cover FROM %DeepSee_Dashboard.Definition "
	set basefilter = "WHERE ((NOT (foldername %STARTSWITH '$TRASH' or foldername %STARTSWITH 'HIDDEN')) OR foldername IS NULL) AND (MDX2JSON.IsItemVisible(fullName) = 1) "
	return:folderName="" basesql _ basefilter
	set filter = "AND folderName %STARTSWITH '" _ folderName _"'"
	return basesql _ basefilter _ filter
}

/// Extracts dashboard cover from %DeepSee.Dashboard.Definition class bookCover property.<br>
/// Usage: Select MDX2JSON.Dashboard_GetDashCover(bookCover) FROM %DeepSee_Dashboard.Definition
ClassMethod GetDashCover(bookCover As %String = "") As %String [ SqlName = GetDashCover, SqlProc ]
{
	do ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(bookCover,,.obj,1)
	return:$isobject(obj) obj.background.src
	return ""
}

/// Check visibility of folder item to current user.<br>
/// Usage: Select fullname, MDX2JSON.IsItemVisible(fullname) FROM %DeepSee_Dashboard.Definition
ClassMethod IsItemVisible(fullName As %String = "") As %String [ SqlName = IsItemVisible, SqlProc ]
{
	set visible = ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(fullName)
	return:visible=1 1
	return 0
}

/// Resolve a localized text string at run time.<br>
/// A localized string can take the following forms:<br>
/// "String" -- not localized.<br>
/// "$$$String" -- equivalent to $$$Text("String","DeepSeeUser")<br>
/// "$$$String/Domain" -- equivalent to $$$Text("String","Domain")<br>
/// Equivalent to ##class(%DeepSee.UserPortal.Utils).%ResolveText(), but in SQL context<br>
/// Usage: Select MDX2JSON.Dashboard_ResolveText(title) FROM %DeepSee_Dashboard.Definition
ClassMethod ResolveText(Text As %String) As %String [ SqlName = ResolveText, SqlProc ]
{
	return ##class(%DeepSee.UserPortal.Utils).%ResolveText(Text)
}

/// Opens DeepSee dashboard by it's name. Returns status of aatempt to locate and open dashboard.
/// <b>DashName</b> - fullName property of %DeepSee.Dashboard.Definition class.<br>
/// <b>Dashboard</b> - OREF to opened dashboard would be passed here upon successfull execution.
ClassMethod OpenDashboardByName(DashName As %Integer, Output Dashboard As %DeepSee.Dashboard.Definition) As %Status
{
	 kill Dashboard
	 
	 set id = ""
	 set global = ##class(MDX2JSON.DashboardRS).#global
	 set dashclass = ##class(MDX2JSON.DashboardRS).#dashclass
	 for {
	 	set id = $order(@global@(id))
	 	quit:id=""
	 		
	 	/// first we check that it's a dashboard (not a pivot, etc.)
		set oid = ##class(%DeepSee.UserLibrary.FolderItem).%ComposeOid(id)
	    do ##class(%DeepSee.UserLibrary.FolderItem).%OnDetermineClass(oid, .class)
	    CONTINUE:class'=dashclass
	    
	    /// second we check that it's the one we need
	    quit:$ZCVT(##class(MDX2JSON.DashboardRS).GetDashFullName(id),"L")=$ZCVT(DashName,"L")
	 }
	 return:id="" $$$ERROR($$$GeneralError,"Dashboard " _ DashName _ " does not exist")
	 set Dashboard = ##class(%DeepSee.Dashboard.Definition).%OpenId(id,,.st)
	 return st
}

/// Converts %DeepSee.Dashboard.Definition widgets into %ZEN.proxyObject.
ClassMethod WidgetsToProxyObject(Dashboard As %DeepSee.Dashboard.Definition, Output Widgetlist As %ZEN.proxyObject) As %Status
{
	#Dim widget As %DeepSee.Dashboard.Widget
	
	set Widgetlist = $$$NewDynObj
	set Widgetlist.children = $$$NewDynObjList
	set Widgetlist.displayInfo = ..GetDashboardDisplayInfo(Dashboard)
	set Widgetlist.info = ..GetDashboardInfo(Dashboard)

	set st = $$$OK
	try {
		for i=1:1:Dashboard.widgets.Count() {
			$$$Insert(Widgetlist.children,..WidgetToProxyObject(Dashboard.widgets.GetAt(i), ..GetWidgetCube(Dashboard, i)))
		}
	} catch ex {
		set st = ex.AsStatus()
		do ex.Log()
	}
	return st
}

/// Converts relevant parts of %DeepSee.Dashboard.Widget object into %ZEN.proxyObject.
ClassMethod WidgetToProxyObject(Widget As %DeepSee.Dashboard.Widget, CubeName As %String) As %ZEN.proxyObject [ Internal ]
{
	set obj = $$$NewDynObj

	if (Widget.dataSource '= "") {
		set st = ..GetMdx(Widget.dataSource, .mdx, .basemdx)
		set obj.dataSource = Widget.dataSource
	} elseif (Widget.dataLink '= "") {
		// Linked widgets processing
		set mdx = ""
		set basemdx = ""
		set obj.Link = Widget.dataLink
	}
	
	// datasource is a kpi
	if $piece(Widget.dataSource, ".", *) = "kpi" {
		set kpiClass = ##class(%DeepSee.Utils).%GetKPIClass(Widget.dataSource)
		set obj.kpitype = $classmethod(kpiClass, "%GetSourceType")
		
	}
	
	// Widget is a portlet
	if Widget.type = "portlet" {
		set portletClass = Widget.subtypeClass
		set:portletClass="" portletClass = Widget.subtype
		set obj.settings = ..PortletSettingsToArray(portletClass)
	}
	 
	set obj.mdx = $g(mdx)
	set obj.name = Widget.name
	set obj.basemdx = $g(basemdx)
	set obj.type =Widget.subtype
	set obj.title = ##class(%DeepSee.UserPortal.Utils).%ResolveText(Widget.title) /// $$$ support
	set obj.key =  Widget.key
	set obj.drillDownDataSource = Widget.drillDownDataSource
	set obj.cube = CubeName
	set obj.displayInfo = ..GetWidgetDisplayInfo(Widget)
	set obj.controls = $$$NewDynObjList
	set obj.dataProperties = $$$NewDynObjList

	for i=1:1:Widget.controls.Count()
	{
		set control = ..WidgetControlToProxyObject(Widget, i, CubeName)
		if $IsObject(control) {
			$$$Insert(obj.controls,control)
		}
	}
	
	for i=1:1:Widget.dataProperties.Count()
	{
		set widgetData = Widget.dataProperties.GetAt(i)
 		d ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(widgetData.override,,.override)
 		set widgetData.override = override
 		set dataProperty = ..WidgetDataPropertyToProxyObject(widgetData)
		if $IsObject(dataProperty) {
			$$$Insert(obj.dataProperties,dataProperty)
		}
	}

	if ##class(%Dictionary.CompiledMethod).%ExistsId("MDX2JSON.Dashboard||Process"_Widget.subtype) {
		do $ClassMethod("MDX2JSON.Dashboard", "Process"_Widget.subtype, Widget, obj)
	}

	if (Widget.properties.Count()>0) {
		set obj.properties = $$$NewDynObj //##class(%ArrayOfDataTypes).%New()
		do {
			set property = Widget.properties.GetNext(.key)
			//do:(key'="") obj.properties.SetAt(property,key)
			do:(key'="") obj.properties.%DispatchSetProperty(key,property)
		} while key'=""
	}
	
	if Widget.overrides.Count()>0 {
		set obj.overrides = $$$NewDynObjList
		do {
			set overridestr = Widget.overrides.GetNext(.key) // we take DeepSee widget override string (in "json" format)
			quit:key=""
			do ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(overridestr,,.override,1) // convert it into %ZEN.proxyObject
			if $IsObject(override) {
				$$$Insert(obj.overrides,override)
			}
		} while key'=""
	}

	return obj
}

ClassMethod WidgetDataPropertyToProxyObject(dataProperty As %DeepSee.Dashboard.DataProperty)
{
	set obj = $$$NewDynObj
	set obj.align = dataProperty.align
	set obj.baseValue = dataProperty.baseValue
	set obj.dataValue = dataProperty.dataValue
	set obj.display = dataProperty.display
	set obj.format = dataProperty.format
	set obj.label = dataProperty.label
	set obj.name = dataProperty.name
	set obj.override = dataProperty.override
	set obj.rangeLower = dataProperty.rangeLower
	set obj.rangeUpper = dataProperty.rangeUpper
	set obj.showAs = dataProperty.showAs
	set obj.style = dataProperty.style
	set obj.subtype = dataProperty.subtype
	set obj.summary = dataProperty.summary
	set obj.summaryValue = dataProperty.summaryValue
	set obj.targetValue = dataProperty.targetValue
	set obj.thresholdLower = dataProperty.thresholdLower
	set obj.thresholdUpper = dataProperty.thresholdUpper
	set obj.valueColumn = dataProperty.valueColumn
	set obj.width = dataProperty.width
	quit obj
}

ClassMethod ProcesscomboChart(Widget As %DeepSee.Dashboard.Widget, Obj As %ZEN.proxyObject)
{

	set Obj.seriesTypes = $$$NewDynDTList
	for i=1:1:Widget.dataSeries.Count()
	{
		$$$Insert(Obj.seriesTypes,Widget.dataSeries.GetAt(i).type)
	}
}

ClassMethod ProcesstreeMapChart(Widget As %DeepSee.Dashboard.Widget, Obj As %ZEN.proxyObject)
{
	do ..ProcesscomboChart(Widget, Obj)
}

ClassMethod ProcesstextMeter(Widget As %DeepSee.Dashboard.Widget, Obj As %ZEN.proxyObject)
{
	set Obj.dataProperties = $$$NewDynDTList
	for i=1:1:Widget.dataProperties.Count()
	{
		set dataProperty = $$$NewDynObj
		if (Widget.dataProperties.GetAt(i)) // check if widget have dataProperties
		{ 
			set widgetData = Widget.dataProperties.GetAt(i)
			set dataProperty = ..WidgetDataPropertyToProxyObject(widgetData)
			if $IsObject(dataProperty) 
			{ 
				$$$Insert(Obj.dataProperties,dataProperty)
			}

	}
	}
}

/// Converts %DeepSee.Dashboard.Control object into %ZEN.proxyObject, handles run-time DeepSee variables.
ClassMethod WidgetControlToProxyObject(Widget As %DeepSee.Dashboard.Widget, Number As %Integer, CubeName As %String) As %ZEN.proxyObject [ Internal ]
{
	set obj = $$$NewDynObj
	set st = Widget.controls.GetAt(Number).%CopyTo(obj) // copy widget control properties to proxyObj

	set obj.label = ##class(%DeepSee.UserPortal.Utils).%ResolveText(obj.label)
	set obj.source = Widget.name

	set:(obj.target="") obj.target = Widget.name

	if ($e(obj.value)="@") {
		set name = $e(obj.value,2,*)
		set value = ##class(%DeepSee.UserPortal.Utils).%GetUserSetting(name,.st)
		if $e(value,1,2)="&[" {
			set obj.value = value
		} else {
			set obj.value = "&[" _ value _ "]"
		}
	}
	// last OR is suppose to populate dashboard with values in case of applyVariable type filter
	set:((obj.action="applyFilter") || (obj.action="setFilter") || (obj.action="applyVariable")) obj.values = ..GetMembersForFilter(CubeName,obj.targetProperty)
	return obj
}

/// Returns MDX string used to create pivot.<br>
/// <b>pPivotName</b> - fullname of pivot. Eg: "KPIs & Plugins/HoleFoods.pivot". Case insensitive.<br>
/// <b>pStatus</b> - Status of query execution.<br>
ClassMethod GetMdx(pPivotName As %String, Output MDX, Output BaseMDX) As %Status
{
	#dim tPivot As %DeepSee.Dashboard.Pivot
	#dim tPivotTable As %DeepSee.Component.pivotTable
	set MDX = ""
	set BaseMDX = ""

	set tPivot = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(pPivotName,.pStatus)
	return:'$IsObject(tPivot) $$$OK
	return:$$$ISERR(pStatus) pStatus

	set tPivotTable = ##class(%DeepSee.Component.pivotTable).%New()
	set pStatus = tPivot.%CopyToComponent(tPivotTable)
	return:$$$ISERR(pStatus) pStatus

	set rs = tPivotTable.%CreateResultSet(.pStatus,.tParms,.tFilterInfo,.tAdvancedFilters,.BaseMDX) // returns tQueryText - mdx without filters
	return:$$$ISERR(pStatus) pStatus

	set pStatus = tPivotTable.%GetFilterInfo(.tFilterInfo,.tAdvancedFilters)
	//return:$$$ISERR(pStatus) pStatus

	if (($d(tFilterInfo)=0) &&($d(tAdvancedFilters)=0)) {
		set MDX = BaseMDX // no filters, so we're good
	} else {
		set rs = tPivotTable.%CreateResultSet(.pStatus,.tParms,.tFilterInfo,.tAdvancedFilters,.MDX) // returns tQueryText - mdx with filters
		return:$$$ISERR(pStatus) pStatus
	}

	// Remove \n
	set MDX = $TR(MDX,$C(10),"")
	set BaseMDX = $TR(BaseMDX,$C(10),"")

	return pStatus
}

/// Return list of possible filter member values for a given dashboard data source and filter.
/// Returns list of %ZEN.proxyObject:<br/>
ClassMethod GetMembersForFilter(DataSource As %String, Filter As %String) As %ListOfObjects
{
	set st = ##class(%DeepSee.Dashboard.Utils).%GetMembersForFilter(DataSource,Filter,.tMembers,.tDefaultFilterValue,,.tRelatedFilters,0,,.tValueList)
	set members = $$$NewDynObjList

	set key = $order(tMembers(""))
	while (key '= "") {
		set member = $$$NewDynObj
		set member.name = $lg(tMembers(key),1)
		set member.path = $lg(tMembers(key),2)
		set member.info = $lg(tMembers(key),3)
		set key = $order(tMembers(key))
		$$$Insert(members,member)
	}
	return members
}

/// Converts %DeepSee.Dashboard.Definition display information into %ZEN.proxyObject.
ClassMethod GetDashboardDisplayInfo(Dashboard As %DeepSee.Dashboard.Definition) As %ZEN.proxyObject
{
	set DisplayInfo = $$$NewDynObj
	set DisplayInfo.snapToGrid = Dashboard.snapTo // Dashboard is in "snap to grid" mode.
	set DisplayInfo.gridMode = Dashboard.snapGrid // Dashboard uses the new snapGrid layout mode.
	set DisplayInfo.gridRows = Dashboard.gridRows
	set DisplayInfo.gridCols = Dashboard.gridCols
	return DisplayInfo
}

/// Converts %DeepSee.Dashboard.Widget display information into %ZEN.proxyObject.
ClassMethod GetWidgetDisplayInfo(Widget As %DeepSee.Dashboard.Widget) As %ZEN.proxyObject
{
	set DisplayInfo = $$$NewDynObj

	set DisplayInfo.top = Widget.top
	set DisplayInfo.left = Widget.left
	set DisplayInfo.width = Widget.width
	set DisplayInfo.height = Widget.height
	set DisplayInfo.topCol = Widget.homeColL
	set DisplayInfo.leftRow = Widget.homeRowL
	set DisplayInfo.colWidth = Widget.colSpanL
	set DisplayInfo.rowHeight = Widget.rowSpanL

	return DisplayInfo
}

/// Converts %DeepSee.Dashboard.Definition display information into %ZEN.proxyObject.
ClassMethod GetDashboardInfo(Dashboard As %DeepSee.Dashboard.Definition) As %ZEN.proxyObject
{
	set Info = $$$NewDynObj
	set Info.title = ##class(%DeepSee.UserPortal.Utils).%ResolveText(Dashboard.title)

	return Info
}

/// Returns name of widget's pivot source cube.
ClassMethod GetWidgetCube(Dashboard As %DeepSee.Dashboard.Definition, WidgetNumber As %Integer) As %String
{
	set datasource = ..DetermineWidgetDataSource(Dashboard, WidgetNumber)
	
	if ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(datasource,.id) {
		set cube = ##class(%DeepSee.Dashboard.Pivot).cubeNameGetStored(id)
	} else {
		// KPIs and Worksheets
		set cube = datasource
	}
	return cube
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

/// Return datasource if one exists, if it's a linked widget then follow the link and get that datasource.
ClassMethod DetermineWidgetDataSource(Dashboard As %DeepSee.Dashboard.Definition, WidgetNumber As %Integer) As %String
{
	set datasource = Dashboard.widgets.GetAt(WidgetNumber).dataSource
	return:datasource'="" datasource
	
	set datalink =  Dashboard.widgets.GetAt(WidgetNumber).dataLink
	return:datalink="" ""
	set WidgetNumber = ..GetWidgetNumberByName(Dashboard, datalink)
	return ..DetermineWidgetDataSource(Dashboard, WidgetNumber)
}

/// Determines position of a widget in dashboard's widget list. 
ClassMethod GetWidgetNumberByName(Dashboard As %DeepSee.Dashboard.Definition, WidgetName As %String) As %Integer
{
	for i=1:1:Dashboard.widgets.Count() {
		return:(Dashboard.widgets.GetAt(i).name = WidgetName) i
	}
	return ""
}

/// On return, <var>pInfo</var> can contain a list of settings in the form:<br/>
/// pInfo(n) = $LB(name,value,type,caption,title)<br/>
/// <var>name</var> is the logical name of the setting.<br/>
/// <var>value</var> is the default value of the setting.<br/>
/// <var>type</var> indicates the type of the setting. This determines the control
/// displayed to get the value of the setting. If omitted the type is assumed to be a string.
/// The type can be: "%Integer", "%Boolean", or "ENUM^caption1:value1,caption2:value2".<br/>
/// <var>caption</var> is the localized caption of the setting.<br/>
/// <var>title</var> is an optional tooltip displayed for the setting.<br/>
/// Custom portlet settings can be controlled using the SETTINGS=PORTLET parameter in the 
/// dashboard URL 
/// set list = ##class(MDX2JSON.Dashboard).KPISettongsToArray("DeepSee.Model.PortletDemo.ClockPortlet")
ClassMethod PortletSettingsToArray(Class As %Dictionary.CacheClassname) As %ListOfObjects
{
	do $classmethod(Class, "%OnGetPortletSettings", .info)
	set list = $$$NewDynObjList
	
	set key = $o(info(""))
	while key'="" {
		set settingInfo = info(key)
		
		set setting = $$$NewDynObj
		set setting.name = $lg(settingInfo, 1)
		set setting.value = $lg(settingInfo, 2)
		set setting.type = $lg(settingInfo, 3)
		set setting.caption = $lg(settingInfo, 4)
		set setting.title = $lg(settingInfo, 5)
		
		$$$Insert(list, setting)	
		set key = $o(info(key))	
	}
	
	return list
}

}
