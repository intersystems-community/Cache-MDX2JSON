Include MDX4JSON.MDX4JSON

/// Class for Setting/Getting User <b>settings</b> for various <b>apps</b>.<br>
/// Can also export/import dettings to/from <b>files</b>.
Class MDX4JSON.Users
{

/// Get <b>App</b> configuration for <b>User</b>
ClassMethod GetConfig(App As %String, User As %String = {$Username}) As %String
{
	set App = $zcvt(App, "U")
	set config = $g($$$Global($$$Settings, User, App))
	set:((config="")||($Roles[$$$DefaultSettingsRole)) config = $g($$$Global($$$Settings, $$$DefaultUser, App))
	return config
}

/// Set <b>App</b> configuration for <b>User</b> equal to <b>Config</b>
ClassMethod SetConfig(App As %String, Config As %String = "", User As %String = {$Username}) As %Status
{
	set App = $zcvt(App, "U")
	if ($Roles[$$$DefaultSettingsRole) {
		set $$$Global($$$Settings, $$$DefaultUser, App) = Config
	} else {
		set $$$Global($$$Settings, User, App) = Config
	}
	return $$$OK
}

/// Set <b>App</b> configuration for all Users equal to <b>Config</b>
ClassMethod SetConfigForAllUsers(App As %String, Config As %String = "") As %Status
{
	new $Namespace
	set $Namespace = "%SYS"
	return:'($$$IOwnAllRole) $$$ERROR($$$AccessDenied)

	set rs=##Class(%ResultSet).%New("Security.Users:List")
	set st = rs.Execute()
	while rs.Next() {
		set st=$$$ADDSC(st,..SetConfig(App, Config, rs.Get("Name")))
	}
	kill rs
	return st
}

/// Move <b>App</b> configuration for all Users from Security.Users:Attributes property to $$$Global($$$Settings, App)
ClassMethod MoveConfig(App As %String) As %Status
{
	set ns = $Namespace
	zn "%SYS"
	return:'($$$IOwnAllRole) $$$ERROR($$$AccessDenied)

	set rs = ##Class(%ResultSet).%New("Security.Users:List")
	set st = rs.Execute()
	while rs.Next() {
		set Config = ..OldGetConfig(App, rs.Get("Name"))
		set st = $$$ADDSC(st,..SetConfig(App, Config, rs.Get("Name")))
	}
	
	zn ns
	return st
}

/// Map <b>Global</b> From <b>Database</b> into <b>Namespace</b>
ClassMethod MapGlobal(Namespace As %String, Global As %String, From As %String) As %Status
{
	new $Namespace
	set $Namespace = "%SYS"
	set Namespace=$ZCVT(Namespace,"U")

	if '##Class(Config.MapGlobals).Exists(Namespace,Global) {
		kill p
		set p("Database")=From
		set st = ##Class(Config.MapGlobals).Create(Namespace,Global,.p,,1)
		return:$$$ISERR(st) st
	}
	
	set st = ##Class(Config.CPF).Write()
	return:$$$ISERR(st) st
	set st = ##Class(Config.Map).MoveToActive(Namespace)
	return:$$$ISERR(st) st
 	set st = ##Class(Config.Namespaces).Load(Namespace)
	
	return st
}

/// Get <b>App</b> configuration for <b>User</b> from Security.Users:Attributes property
ClassMethod OldGetConfig(App As %String, User As %String = {$Username}) As %String
{
	set ns = $Namespace
	zn "%SYS"
	set st =##class(Security.Users).Get(User,.Properties)
	zn ns
	return $lg($g(Properties("Attributes",App)))
}

/// Export <b>App</b> configuration for <b>User</b> to <b>File</b>
ClassMethod ExportConfig(App As %String, User As %String = {$Username}, FileName As %String) As %Status
{

	set config = ..GetConfig(App,User)
	set stream=##class(%Stream.FileCharacter).%New()
	set stream.TranslateTable="UTF8"
	set st=stream.LinkToFile(FileName)
	return:$$$ISERR(st) st
	set st=stream.Write(config)
	return:$$$ISERR(st) st
	set st=stream.%Save()
	return st
}

/// Import <b>App</b> configuration for <b>User</b> from <b>File</b>
ClassMethod ImportConfig(App As %String, User As %String = {$Username}, FileName As %String) As %String
{
	set stream=##class(%Stream.FileCharacter).%New()
	set stream.TranslateTable="UTF8"
	set st=stream.LinkToFile(FileName)
	return:$$$ISERR(st) st
	set config = ""
	while 'stream.AtEnd {
		set config = config _stream.Read()
	}
	set st = ..SetConfig(App,config,User)
	return st
}

/// Get Current user favorites
ClassMethod GetFavorites() As %String
{
	set st = ##class(%DeepSee.UserPortal.Utils).%GetFavoritesForUser(.Favorites)
	return:$$$ISERR(st) st
	set st = ##class(%ZEN.Auxiliary.jsonProvider).%ArrayToJSON($lb("FullName","ShortName","Folder","Tip","Type","Icon","AddDate","URL"),.Favorites)
	return:$$$ISERR(st) st
	return $$$OK
}

/// Move config from old storage schema to a new one
ClassMethod MoveConfigNS(TargetNS = "MDX4JSON")
{
	new $Namespace
	#dim mappedlist As %ListOfDataTypes
	#dim userlist As %ListOfDataTypes
	set mappedlist = ##class(MDX4JSON.AbstractREST).GetMappings().GetAt("Mapped")
	set userlist = ..GetUserList()
	for i = 1:1:mappedlist.Count() {
		zn mappedlist.GetAt(i)
		for j=1:1:userlist.Count() {
			if ..GetConfig("DeepSeeWeb",userlist.GetAt(j))'="" {
				set settings($$$Settings, userlist.GetAt(j), $ZCVT($Namespace,"U")) = ..GetConfig("DeepSeeWeb",userlist.GetAt(j))
			}
		}
		m ^MDX4JSONOld = $$$Global
		k $$$Global	
	}
	zn TargetNS
	m $$$Global = settings
}

/// Move config from new storage schema to an old one
ClassMethod MoveBack(TargetNS = "MDX4JSON")
{
	new $Namespace
	set mappedlist = ##class(MDX4JSON.AbstractREST).GetMappings().GetAt("Mapped")
	for i = 1:1:mappedlist.Count() {
		zn mappedlist.GetAt(i) 
		m $$$Global = ^MDX4JSONOld
	}
}

/// Get list of all users
ClassMethod GetUserList() As %ListOfDataTypes
{
	new $Namespace
	set $Namespace = "%SYS"
	set userlist = ##class(%ListOfDataTypes).%New()
	set statement = ##class(%SQL.Statement).%New()
    set status = statement.%PrepareClassQuery("Security.Users","List")
    if $$$ISERR(status) { do $system.OBJ.DisplayError(status) }
    set resultset = statement.%Execute()
    while resultset.%Next() {
        do userlist.Insert(resultset.%Get("Name"))
	}
	return userlist
}

}
