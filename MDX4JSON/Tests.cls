Include MDX4JSON.MDX4JSON

/// Classes with support methods for testing MDX4JSON
Class MDX4JSON.Tests
{

Parameter LastCommit As %String = "a8e0524a0048583d0cf37ca782cbf35e89bf27af";

Parameter LastCommitTS As %TimeStamp = "2021-12-01 00:00:00.000";

/// Count project length in loc
/// do ##class(MDX4JSON.Tests).ProjectLength()
ClassMethod ProjectLength(Mask As %String = "MDX4JSON") As %String
{
	 Set rset = ##class(%ResultSet).%New("%DynamicQuery:SQL")
	 Do rset.Prepare("SELECT Name FROM %Dictionary.ClassDefinition WHERE NOT Name %STARTSWITH '%sqlcq' AND Name [ '"_Mask_"'")
	 Do rset.Execute()
	 Set count = 0

	 While (rset.Next()) {
		 Set class = rset.Data("Name")
		 Do ##class(%Compiler.UDL.TextServices).GetTextAsArray($Namespace, class, .raw)
		 Set lines = $O(raw($C(0)), -1)
		 Write class, $JUSTIFY("",30-$L(class)), $J(lines,5), !
		 Set count = count + lines
	 }
	 Write "Total ", $JUSTIFY("",24), $J(count,5)
}

/// Entry point to move dashboards into mobile folder<br>
/// Moves all DeepSee folders into Mobile folder (creates folder, if required)
ClassMethod MoveFoldersIntoMobile(Namespace = {$Namespace}) As %Status
{
	Set mobileid =..CreateMobileFolder(Namespace)
	Set ns =$namespace
	Zn Namespace
	&sql(UPDATE %DeepSee_UserLibrary.Folder SET folder=:mobileid WHERE folder is null AND name != 'Mobile')
	Zn ns
	Do ##class(MDX4JSON.Tests).MoveWidgetsDSIntoMobile(Namespace)
	Return SQLCODE
}

/// Creates DeepSee folder Mobile in <b>Namespace</b><br>
ClassMethod CreateMobileFolder(Namespace = {$Namespace}) As %Integer
{
	Set ns =$namespace
	Zn Namespace
	&sql(SELECT ID into :ID FROM %DeepSee_UserLibrary.Folder WHERE folder is null AND name = 'Mobile')
	Zn ns
	Return:$ISVALIDNUM(ID) ID

	Set folder = ##class(%DeepSee.UserLibrary.Folder).%New()
	Set folder.name = "Mobile"
	W $System.Status.GetErrorText(folder.%Save())

	Return folder.%Id()
}

/// Moves widgets datasources into Mobile folder
ClassMethod MoveWidgetsDSIntoMobile(Namespace = {$Namespace}) As %Status
{
	Set ns =$namespace
	Zn Namespace
		&sql(DECLARE sql1 CURSOR FOR
		SELECT ID INTO :ID FROM %DeepSee_Dashboard.Definition)

	&sql(OPEN sql1)
	&sql(FETCH sql1)
	While (SQLCODE = 0) {
		Set Dashboard = ##class(%DeepSee.Dashboard.Definition).%OpenId(ID,,.st)
		For i=1:1:Dashboard.widgets.Count() {
			Set pivot = Dashboard.widgets.GetAt(i).dataSource
			If ((##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(pivot)=0) && (##class(%DeepSee.UserLibrary.Utils).%FolderItemExists("Mobile/"_pivot)=1))
			{
				Set Dashboard.widgets.GetAt(i).dataSource = "Mobile/"_pivot
			}
		}
		Do Dashboard.%Save()
		Set Dashboard=""
		&sql(FETCH sql1)
	}
	&sql(CLOSE sql1)

	Zn ns
	Return $$$OK
}

/// do ##class(MDX4JSON.Tests).DynamicObjects()
ClassMethod DynamicObjects()
{
	set obj = $$$NewDynObj
	set obj.prop = "val"
	$$$DynObjToJSON(obj)

	set dtList = $$$NewDynDTList
	set a = 1
	$$$Insert(dtList,a)
	$$$Insert(dtList,"a")
	$$$ListToJSON(dtList)
}

/// do ##class(MDX4JSON.Tests).RenderSpeed()
ClassMethod RenderSpeed(MDX As %String, Count As %Integer(MINVAL=1) = 10)
{
	Set:$d(MDX)'=1 MDX = "SELECT NON EMPTY [Product].[P1].[Product Category].Members ON 0,NON EMPTY [Outlet].[H1].[Region].Members ON 1 FROM [HoleFoods]"
	Set RS = ##class(MDX4JSON.Utils).GetResultSet(MDX,.st)
	Write $System.Status.GetErrorText(st)
	Set obj = RS.ToProxyObject(.st)
	Write $System.Status.GetErrorText(st)
	Set od=$io
	Set nul=##class(%Device).GetNullDevice() //"\\.\nul" // /dev/null/ - UNIX
	Open nul
	Use nul

	Set startTime = $NOW()
	For i = 1:1:Count {
		$$$DynObjToJSON(obj)
	}
	Set endTime = $NOW()

	Set time = $p(endTime,",",*) - $p(startTime,",",*)
	Use od
	Close nul
	Write "Iterations: ",Count,!
	Write "Time Total ",time,!
	Write "Time Average: ",time/Count
}

/// Iterate over all dashboards in a namespace, for each iterate over widgets.
/// Changes widget key if previously encountered
ClassMethod MakeWidgetKeyUnique()
{
	set rs = ##class(%DeepSee.Dashboard.Definition).ExtentFunc()
	set WidgetKeyList=""
	while rs.%Next() {
		 set Dash = ##class(%DeepSee.Dashboard.Definition).%OpenId(rs.%Get("ID"))
		 for i=1:1:Dash.widgets.Count() {
			 set WidgetKey = Dash.widgets.GetAt(i).key
			 if $LF(WidgetKeyList,WidgetKey) {
				 write "Duplicate dash: ", rs.%Get("ID"), " oldkey: ", WidgetKey
				 // generate new randow widget key
				 do {
				 	set WidgetKey = $R(1000000000)
				 } while ($LF(WidgetKeyList,WidgetKey)'=0)
				 set WidgetKeyList = WidgetKeyList _$LB(WidgetKey)
				 set Dash.widgets.GetAt(i).key = WidgetKey
				 write "newkey: ", WidgetKey, !
				 write $System.Status.GetErrorText(Dash.%Save())
			 } else {
				 set WidgetKeyList = WidgetKeyList _$LB(WidgetKey)
			 }
		 }
   }
}

/// Hook for Cache-Tort-Git source-control plug-in.<br>
/// Sets LastCommit parameter to last successful commit and exports this class.
ClassMethod OnCommit(Command, InternalName) As %Status
{
	return:Command'="commit" $$$OK
	set Status = ..SetParameter(, "LastCommit", ..GetLastCommitHash())
	return:$$$ISERR(Status) Status
	set Status = ..SetParameter(, "LastCommitTS", $ZDT($ZTIMESTAMP, 3, 1, 3))
	return:$$$ISERR(Status) Status
	do ##class(%SourceControl.Git.Utils).UpdateRoutineTSH("MDX4JSON.Tests.cls")
	return ##class(%SourceControl.Git.Utils).ExportItem("MDX4JSON.Tests.cls")
}

/// This method returns last commit SHA-1 hash of <var>Branch</var>
/// in Git repository in <var>RepoFolder</var>.<br>
/// To get current namespace repository you need to use
/// Cache-Tort-Git source-control plug-in
ClassMethod GetLastCommitHash(RepoFolder As %String = {##class(%SourceControl.Git.Utils).TempFolder()}, Branch = "master") As %String
{
	set GitDir = ##class(%File).SubDirectoryName(RepoFolder,".git")
	set RefDir = ##class(%File).SubDirectoryName(GitDir,"refs")
	set HeadRefDir = ##class(%File).SubDirectoryName(RefDir, "heads", 1)
	set HeadRefFileName = HeadRefDir _ Branch
	set HeadRefFile = ##class(%File).%New(HeadRefFileName)
	do HeadRefFile.Open("R")
	set SHAHash = HeadRefFile.ReadLine()
	do HeadRefFile.Close()
	return SHAHash
}

/// Set Class Parameter equal to Value<
ClassMethod SetParameter(Class As %String = {$classname()}, Parameter As %String, Value As %String) As %Status
{
	set Parameter = ##class(%Dictionary.ParameterDefinition).IDKEYOpen(Class, Parameter)
	set Parameter.Default = Value
	return Parameter.%Save()
}

}
