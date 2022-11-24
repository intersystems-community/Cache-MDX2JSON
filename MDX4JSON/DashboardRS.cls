/// Custom result set to get dashboard list, visible to user in a specific folder
Class MDX4JSON.DashboardRS Extends %SQL.CustomResultSet
{

Parameter global = "^DeepSee.FolderItemD";

Parameter dashclass = "%DeepSee.Dashboard.Definition";

Property title As %String;

Property path As %String;

Property cover As %String;

Property id As %String [ Private ];

Property folder As %String [ Private ];

Method %OpenCursor(folderName As %String = "") As %Status
{
	return:((folderName'="") && ('$IsObject(##class(%DeepSee.UserLibrary.Utils).%FindFolder(folderName)))) $$$ERROR($$$GeneralError,"Folder " _ folderName _ " does not exist")
    set ..id = ""
    set ..folder = folderName
    return $$$OK
}

Method %Next(ByRef sc As %Library.Status) As %Integer [ PlaceAfter = %Execute ]
{
    set sc = $$$OK
    do ..SetNextId()
    set id = ..id
    return:id="" $$$NO
    
    set ..title = ##class(%DeepSee.UserPortal.Utils).%ResolveText(##class(%DeepSee.UserLibrary.FolderItem).titleGetStored(id))
    set ..path =  ..GetDashFullName(id)
    set ..cover = ##class(MDX4JSON.Dashboard).GetDashCover(##class(%DeepSee.UserLibrary.FolderItem).bookCoverGetStored(id))
    
    return $$$YES
}

/// Iterate over data global till we find dashboard definition
/// thet satisfies all conditions
Method SetNextId()
{
	set ..id = $order(@..#global@(..id))
    if ((..id'="") && ('..CheckConditions(..id))) {
	    // we are not at the last row and we failed condition check
	    // so we get the next id
	    do ..SetNextId()	
    }
}

/// Check if element with that id satisfies our conditions
Method CheckConditions(id) As %Boolean
{
	/// first we check that it's a dashboard (not a pivot, etc.)
	set oid = ##class(%DeepSee.UserLibrary.FolderItem).%ComposeOid(id)
    do ##class(%DeepSee.UserLibrary.FolderItem).%OnDetermineClass(oid, .class)
    return:class'=..#dashclass $$$NO
    
    /// second that it's not a hidden or deleted dashboard
    set folder = ##class(%DeepSee.UserLibrary.FolderItem).folderGetStored(id)
    set folderpath = ##class(%DeepSee.UserLibrary.Folder).%GetFullName(folder)
    return:(($extract(folderpath,1,6)="$TRASH") || ($extract(folderpath,1,6)="$TRASH")) $$$NO

    /// third we check if a dashboard is in a correct folder
    return:($extract(folderpath,1,$length(..folder))'=..folder) $$$NO
    
    /// fourth we check if the user has access to a dashboard
	return:'..CheckItemResource(id) $$$NO
	
	return $$$YES
}

/// Get dashboard full name by id
ClassMethod GetDashFullName(id As %String)
{
	set folder = ##class(%DeepSee.UserLibrary.FolderItem).folderGetStored(id)
    set name = ##class(%DeepSee.UserLibrary.FolderItem).nameGetStored(id)
    return ##class(%DeepSee.Dashboard.Definition).fullNameCompute(id, folder, name)
}

/// Test if the current user has access to this item.
ClassMethod CheckItemResource(id As %String, privilege As %String = "USE") As %Boolean
{
	set access = $$$NO
	set resource = ..GetItemResource(id)
	if ((resource="")||($System.Security.Check(resource, privilege))) {
		set access = $$$YES
	}
	return access
}

/// Get the resource value for this item.
ClassMethod GetItemResource(id As %String) As %String
{
	set resource = ##class(%DeepSee.UserLibrary.FolderItem).resourceGetStored(id)
	if (resource="") {
		// inherit from folder
		if ##class(%DeepSee.UserLibrary.FolderItem).folderGetStored(id)'="" {
			set resource = ..GetFolderResource(##class(%DeepSee.UserLibrary.FolderItem).folderGetStored(id))
		}
	}
	return resource
}

/// Get the resource value for this folder.
ClassMethod GetFolderResource(folderId As %String) As %String
{
	if (##class(%DeepSee.UserLibrary.Folder).resourceGetStored(folderId)'="") {
		return ##class(%DeepSee.UserLibrary.Folder).resourceGetStored(folderId)
	} elseif (##class(%DeepSee.UserLibrary.Folder).folderGetStored(folderId)'="") {
		return ..GetFolderResource(##class(%DeepSee.UserLibrary.Folder).folderGetStored(folderId))
	}
	return ""
}

/// Get all dashes from SAMPLES namespace
/// do ##class(MDX4JSON.DashboardRS).Test()
ClassMethod Test(folderName As %String = "")
{
	new $namespace
	set $namespace = "Samples"
	set rs = ..%New(,folderName)
	do rs.%Display()
}

///  Execute query and output results as JSON
ClassMethod WriteJSON(folderName As %String = "")
{
	#define CRLF 							$c(13,10)
	#define ZENJSISNUM(%val)				($IsValidNum(%val)&&(%val=+(%val)))
	#define ZENJSNUM(%num)					$fnumber(%num,"LON")
	#; JSON utility macros that use the JSON translation table instead of the JS translation table
	#define ZENJSTABLE(%format)				("JS"_$S(%format["u":"ML",1:""))
	#define ZENJSONTABLE(%format)			("JSON"_$S((%format["u"):"ML",1:""))
	#define ZENJSONESCAPE(%str,%format)		$S(%format["s":$ZCVT(%str,"O",$$$ZENJSONTABLE(%format)),1:$Replace($ZCVT(%str,"O",$$$ZENJSTABLE(%format)),"\'","'"))
	#define ZENJSONSTR(%str,%format)		(""""_$$$ZENJSONESCAPE(%str,%format)_"""")
	#define ZENJSONPROP(%prop,%format)		$$$ZENJSONSTR(%prop,%format)
	#define ZENJSONVALUE(%val,%format)		$S($$$ZENJSISNUM(%val):$$$ZENJSNUM(%val),$C(0)=(%val)||$ListValid(%val):"""""",1:$$$ZENJSONSTR(%val,%format))
	#define ZENJSONPAIR(%pr,%val,%format)	$$$ZENJSONPROP(%pr,%format)_":"_$$$ZENJSONVALUE(%val,%format)
	
	set rs = ..%New(,folderName)
	write "{ ""children"":["
	set separator=0
	while rs.%Next() {
		write:separator ",",$$$CRLF
		write "{"
        write $$$ZENJSONPAIR("title",rs.title,""),","
        write $$$ZENJSONPAIR("path",rs.path,""),","
        write $$$ZENJSONPAIR("Cover",rs.cover,"")
        write "}"
        
        set separator = 1
    }
    write "]}"
}

}
