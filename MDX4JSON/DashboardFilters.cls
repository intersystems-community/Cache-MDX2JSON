Include MDX4JSON.MDX4JSON

/// Class with methods related to DeepSee Dashboard and Widget processing.
Class MDX4JSON.DashboardFilters Extends MDX4JSON.Dashboard
{

/// Converts %DeepSee.Dashboard.Definition widgets into %ZEN.proxyObject.
ClassMethod WidgetsToProxyObject(Dashboard As %DeepSee.Dashboard.Definition, Output Widgetlist As %ZEN.proxyObject) As %Status
{
	#Dim widget As %DeepSee.Dashboard.Widget
	set Widgetlist = $$$NewDynObj
	set Widgetlist.widgets = $$$NewDynObjList
	set Widgetlist.filters = $$$NewDynObjList
	set Widgetlist.displayInfo = ..GetDashboardDisplayInfo(Dashboard)
	set Widgetlist.info = ..GetDashboardInfo(Dashboard)

	set st = $$$OK
	try {
		for i=1:1:Dashboard.widgets.Count() {
			$$$Insert(Widgetlist.widgets,..WidgetToProxyObject(Dashboard.widgets.GetAt(i), ..GetWidgetCube(Dashboard, i)))
			#dim filters As %ListOfObjects
			set filters = ..WidgetFiltersToProxyObject(Dashboard.widgets.GetAt(i), ..GetWidgetCube(Dashboard, i))
			for j=1:1:$$$ListSize(filters) {
				$$$Insert(Widgetlist.filters,$$$ListGet(filters,j))
			}
		}
	} catch ex {
		set st = ex.AsStatus()
		do ex.Log()
	}
	return st
}

/// Converts relevant parts of %DeepSee.Dashboard.Widget object into %ZEN.proxyObject.
ClassMethod WidgetFiltersToProxyObject(Widget As %DeepSee.Dashboard.Widget, CubeName As %String) As %ZEN.proxyObject [ Internal ]
{
	set obj = $$$NewDynObjList
	for i=1:1:Widget.controls.Count()
	{
		set filter = ..WidgetFilterToProxyObject(Widget, i, CubeName)
		if $IsObject(filter){
			$$$Insert(obj,filter)
		}
	}
	return obj
}

/// Converts %DeepSee.Dashboard.Control object into %ZEN.proxyObject, handles run-time DeepSee variables.
ClassMethod WidgetControlToProxyObject(Widget As %DeepSee.Dashboard.Widget, Number As %Integer, Cube As %String) As %ZEN.proxyObject [ Internal ]
{
	return:((Widget.controls.GetAt(Number).action="applyFilter") || (Widget.controls.GetAt(Number).action="setFilter")) ""
	return ##class(MDX4JSON.Dashboard).WidgetControlToProxyObject(Widget,Number,Cube)
}

/// Converts %DeepSee.Dashboard.Control object into %ZEN.proxyObject, handles run-time DeepSee variables.
ClassMethod WidgetFilterToProxyObject(Widget As %DeepSee.Dashboard.Widget, Number As %Integer, Cube As %String) As %ZEN.proxyObject [ Internal ]
{
	return:'((Widget.controls.GetAt(Number).action="applyFilter") || (Widget.controls.GetAt(Number).action="setFilter")) ""
	return ##class(MDX4JSON.Dashboard).WidgetControlToProxyObject(Widget,Number,Cube)
}

}
