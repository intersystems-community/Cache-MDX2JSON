Include MDX2JSON.MDX2JSON

/// This class provides an API for executing queries against DeepSee cubes
/// and viewing the results.<br/>
Class MDX2JSON.ResultSet Extends %DeepSee.ResultSet
{

/// Converts ResultSet to %ZEN.proxyObject.<br>
/// <b>pStatus</b> - Status of execution.<br>
Method ToProxyObject(Output pStatus As %Status) As %ZEN.proxyObject
{
	set ^DeepSee.QueryLog($UserName,$I(^DeepSee.QueryLog($UserName))) = ..%GetQueryText()
	set status = $$$ERROR($$$GeneralError,"Error occured while executing ##class(MDX2JSON.ResultSet).ToProxyObject() method")

	set obj=$$$NewDynObj

	if (..%Query.queryType = "DRILLTHROUGH") {
		set pStatus = $$$ERROR($$$GeneralError, "DRILLTHROUGH queries are not supported")
		return ""
	}

	/*set st = ..%GetQueryStatus(..%Cube,tQueryKey)
	if (st < 100) {
		hang 1
		set st = ..%GetQueryStatus(..%Cube,tQueryKey)
	}

	if (st < 100) {
		set pStatus = st
		return ""
	}*/

	try {			
		set obj.Info = ..InfoToProxyObject() // basic info about cube and query
		quit:obj.Info.percentDone<100
				
		set obj.Cols = ..AxesToListOfObjects() // all axes
		set obj.Data = ..DataToListOfDataTypes() // array of all cells, left-to-right, up-to-down
	} catch ex {
		set pStatus = ex.AsStatus()
		return ""
	}
	set pStatus = $$$OK
	return obj
}

/// Returns meta-information about ResultSet.
Method InfoToProxyObject() As %ZEN.proxyObject
{
	set tCubeIndex = ..%CubeKey
	set tQueryKey = ..%QueryKey
	set tCubeName = $$$UPPER(..%Cube)

	set tAxisCount = ..%GetAxisCount()
	for a = 1:1:tAxisCount {
		set tAxisSize(a) = ..%GetAxisSize(a)
		set tAxisKeys(a) = $G($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"axis",a))
	}

	set info=$$$NewDynObj
	set info.queryKey = tQueryKey
	set info.rowCount = $G(tAxisSize(1))
	set info.colCount = $G(tAxisSize(2))
	set info.colKey = $G(tAxisKeys(1))
	set info.rowKey = $G(tAxisKeys(2))
	set info.percentDone = ..%GetStatus()

	// find name of cube in original case
	set tCubeClass = $G($$$DeepSeeMetaGLVN("cubes",tCubeName))
	set tCubeName = $G($$$DeepSeeMetaGLVN("classes",tCubeClass))								
	set info.cubeName = tCubeName
	set info.cubeClass = tCubeClass
	set info.cubeKey = tCubeIndex

 	set info.numericGroupSeparator = ##class(%SYS.NLS.Format).GetFormatItem("NumericGroupSeparator")
	set info.numericGroupSize = ##class(%SYS.NLS.Format).GetFormatItem("NumericGroupSize")
	set info.decimalSeparator = ##class(%SYS.NLS.Format).GetFormatItem("DecimalSeparator")
									
	return info
}

/// Returns array of Axes
Method AxesToListOfObjects() As %ListOfObjects
{
	set tCubeIndex = ..%CubeKey
	set tQueryKey = ..%QueryKey
	set tAxisCount = ..%GetAxisCount()

	if (($System.Version.GetMajor() <2015) && (tAxisCount>2)) {
		set tAxisCount = 2 //because filters count as axes before 2015.1
	}

	set axes=$$$NewDynObjList
	for a = 1:1:tAxisCount {
		set tAxisSize(a) = ..%GetAxisSize(a)
		set tAxisKeys(a) = $G($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"axis",a))
		$$$Insert(axes,..ProcessOneAxis(tCubeIndex,tAxisKeys(a),a,tAxisSize(a)))
	}

	if ($$$ListSize(axes)=0) {
		set axes = ..GetDefaultAxes()
	}

	return axes
}

Method ProcessOneAxis(CubeIndex, AxisKey, AxisNumber, AxisSize) As %ZEN.proxyObject [ Internal ]
{
	set tCubeName = $$$UPPER(..%Cube)
	set tQueryKey = ..%QueryKey

	set axis=$$$NewDynObj
	set axis.tuples = ..ProcessOneAxisCell(CubeIndex, AxisKey, tCubeName, tQueryKey, AxisNumber, 1, AxisSize)

	return axis
}

Method ProcessOneAxisCell(CubeIndex, AxisKey, CubeName, QueryKey, AxisNumber, Node, AxisSize) As %ZEN.proxyObject [ Internal ]
{
	set cell=$$$NewDynObj

	set tNode = $G($$$DeepSeeAxisGLVN(CubeIndex,AxisKey,"axes",Node))
	set cell.caption = ##class(%DeepSee.UserPortal.Utils).%ResolveText($LG(tNode,5)) // text caption
	set cell.vis = $LG(tNode,2) // visibility helper - does not help (apperently it shows if the cell is the lowest level)  
	// now we process cell children, if any exist
	if ($D($$$DeepSeeAxisGLVN(CubeIndex, AxisKey, "axes", Node, "ch")) = 10) {
		set cell.children = $$$NewDynObjList
		for i=1:1:AxisSize
		{
			set AxisSize = AxisSize
			set key = $G(@..%ResultCacheLocation@(..%CubeKey,..%QueryKey,"leaf",AxisNumber,i))
			set children = ..ProcessOneAxisCell(CubeIndex, AxisKey, CubeName, QueryKey, AxisNumber, key, AxisSize)
			// Append children to cell
			if $isobject(children) {
				if ((children.%IsA("%ZEN.proxyObject")) || (children.%IsA("%Library.Object"))) {
					$$$Insert(cell.children,children)
				} elseif ((children.%IsA("%Collection.AbstractList")) || (children.%IsA("%Library.Array"))) {
					for i=1:1:$$$ListSize(children) {
						$$$Insert(cell.children,$$$ListGet(children,i))
					}
				}
			}
		}
	}

	//To filter out invisible сells
	if (..IsCellNull(cell)=1) {
		return cell.children
	}
	
	try {
		set cell.path = ##class(%DeepSee.Query.Engine).%GetSpecForAxisNode(CubeName, QueryKey, AxisNumber, Node) // MDX cell path
		set:$e(cell.path)="(" cell.path = $e(cell.path, 2, *-1)  // removing redundant parentheses
	} catch ex {
		set cell.path = "path too long"		
	}
	
	set cell.format = $LG(tNode,12) // format for numbers, eg: $## ###.##
	set cell.total = $LG(tNode,8) //COUNT,AVG function
	set cell.type = $LG(tNode,1) // mbr,cmbr,lit,exp
	set cell.valueID = $LG(tNode,6) // id in mdx dimension for mbr, path for cmbr
	set cell.title = $LG(tNode,23)
	
	set cell.headerStyle = $LG(tNode,19)
	set cell.cellStyle = $LG(tNode,18)
	
	set info = $LG(tNode,18)
	if info'="" { // extract aggregation information, leave the rest as css
		set summaryposition = $f(info,"summary")
		if summaryposition>0 {
			set summaryvalue = $e(info,summaryposition+1,$f(info,";",summaryposition)-2)
			set cell.summary = summaryvalue // aggregate function
			set $e(info,summaryposition-7,summaryposition + $l(summaryvalue) + 1) = ""
		}
		set cell.style = info // css
	}
	
	set tDimNo = $LG(tNode,9)
	set tHierNo = $LG(tNode,10)
	set tLevelNo = $LG(tNode,11)
	set tCaption = $LG(tNode, 5)

	do ##class(%DeepSee.Utils).%GetDimensionCaption(CubeName,tDimNo, tHierNo,tLevelNo, .tAxisCaption)
	set cell.dimension = tCaption // cube dimension taken from the name of the axes.
	if (cell.dimension = "") {set cell.dimension = tCaption} // hack for assigne dimension property in case of empty dimension
	

	set:$$$Debug cell.visible = '..IsCellNull(cell,AxisNumber,Node)
	set:$$$Debug cell.node = Node

	return cell
}

/// Determine if cell is an invisible system cell.
Method IsCellNull(Cell)
{
 	
	return:(Cell.caption=0) 1 // typical caption for top-level cell
	return:(Cell.caption=1) 1 // typical caption for top-level cell
	return:(Cell.caption="") 1 // typical caption for top-level cell
	//return:(caption'="") 0
	//return:(path="") 1
	set children = Cell.children
	return:(($isobject(children)) && ($$$ListSize(children)>0)) 0 // cell has children
	
	// in case of cell type='lit'. the 'lit' cell always has the value vis=0, so we can skip it
	// this is also true for type='axis' and type='set' so there is no need to check everything individually
	return:(Cell.vis '= 0) 0 
		

	return 1
}

/// Returns array of cells (left-to-right, up-to-down)
Method DataToListOfDataTypes() As %ListOfDataTypes
{
	set data = $$$NewDynDTList

	set tCubeIndex = ..%CubeKey
	set tQueryKey = ..%QueryKey
	set tAxisCount = ..%GetAxisCount()
	set tAddr = tAxisCount

	set tNodeNo = ""

	// Initial cell address
	for a=1:1:tAxisCount {
		Set tItemNo(a) = $O($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"leaf",a,""),1,tNodeNo)
		Set tAddr(a) = $G(tNodeNo)
	}

	set tNodeNo = ""

	if (tAxisCount = 0) {
		$$$Insert(data,..%GetValue())
	} elseif (tAxisCount = 1) {
		set tRowCount = 1
		set c = 0
		while (tItemNo(1)'="") {
			$$$Insert(data,..%GetValue(tAddr(1)))
			set c = c + 1
			set tItemNo(1) = $O($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"leaf",1,tItemNo(1)),1,tNodeNo)
			set tAddr(1) = tNodeNo
		}
	} else {
		set tCellCount = 0
		while(tItemNo(2)'="") {
				set tItemNo(1) = $O($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"leaf",1,""),1,tNodeNo)
				set tAddr(1) = tNodeNo
				while (tItemNo(1)'="") {
					set tValue = ..%GetValue(tAddr...) // for 2 axes ..%GetValue(tAddr(1),tAddr(2))
					$$$Insert(data,tValue)

					set tItemNo(1) = $O($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"leaf",1,tItemNo(1)),1,tNodeNo)
					set tAddr(1) = tNodeNo
				}
			set tItemNo(2) = $O($$$DeepSeeResultsGLVN(tCubeIndex,tQueryKey,"leaf",2,tItemNo(2)),1,tNodeNo)
			set tAddr(2) = tNodeNo
		}
	}

	return data
}

ClassMethod GetDefaultAxes() As %ListOfObjects [ Internal ]
{
	set axes=$$$NewDynObjList // all axes

	set cell=$$$NewDynObj
	set cell.caption = $$$Text("Count","%DeepSee")
	set cell.format = ""
	set cell.total = "COUNT"
	set cell.type = "msr"
	set cell.valueID = ""
	set cell.path = ""
	set cell.info = ""
	set cell.dimension = "Count"

	set cell2=cell.%ConstructClone()
	set cell2.type = "mbr"
	set cell2.total = ""
	set cell2.caption = ""
	set cell2.dimension = "%Search"

	set axis = $$$NewDynObj // one axis
	set axis.tuples = $$$NewDynObjList //array of cells for one axis
	$$$Insert(axis.tuples,cell)
	$$$Insert(axes,axis)

	set axis2 = $$$NewDynObj
	set axis2.tuples = $$$NewDynObjList
	$$$Insert(axis2.tuples,cell2)
	$$$Insert(axes,axis2)

	return axes
}

}
