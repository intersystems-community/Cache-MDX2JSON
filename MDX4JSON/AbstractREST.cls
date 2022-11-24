Include MDX4JSON.MDX4JSON

/// All logic related to the proceccing of http requests.
Class MDX4JSON.AbstractREST Extends %CSP.REST
{

Parameter UseSession As Integer = 1;

/// This method gets called prior to dispatch of the request. Put any common code here
/// that you want to be executed for EVERY request. If pContinue is set to 0, the
/// request will NOT be dispatched according to the UrlMap. In this case it's the
/// responsibility of the user to return a response.
ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
	Set pContinue = 1
	#dim request As %CSP.Request
	Do %response.SetHeader("Access-Control-Allow-Origin",..GetOrigins())
	Do %response.SetHeader("Access-Control-Allow-Credentials","true")
	Do %response.SetHeader("Access-Control-Allow-Methods","GET, PUT, POST, DELETE, OPTIONS")
	Do %response.SetHeader("Access-Control-Max-Age","10000")
	Do %response.SetHeader("Access-Control-Allow-Headers","Content-Type, Authorization, Accept-Language, X-Requested-With")

	Set %response.CharSet = "utf-8"
	Set %response.ContentType="application/json"

	Set %session.Language=$$MatchLanguage^%occMessages(%request.GetCgiEnv("HTTP_ACCEPT_LANGUAGE"),"%CSP","+s") // Localization support
	Set %response.Language=%session.Language
	
	Set st = ..ConvertRequestBody()
	If $$$ISERR(st) {
		Do ..Http500(st)
		Set pContinue = $$$NO
		Quit st
	}
	
	// Desired execusion namespace
	Set Namespace = %request.Get("Namespace", $namespace)
	Set st = ..CheckNamespace(.Namespace)
	If $$$ISERR(st) {
		Do ..Http500(st)
		Set pContinue = $$$NO 
		Quit
	}
	
	#; Dispatch
	If (Namespace'=$Namespace) {
		zn Namespace
	}
	
    Quit $$$OK
}

/// Converts request into UTF8. Converts request into proxyObject. 
ClassMethod ConvertRequestBody() As %Status
{
	#dim %request As %CSP.Request
	#dim obj As %ZEN.proxyObject

	return:'$isobject(%request.Content) $$$OK //empty request body - nothing to do

	// Convert request body into UTF8 proxyObject
	set content = %request.Content.Read($$$MaxStringLength)
	set content = $ZCVT(content,"I","UTF8")
	set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(content,,.obj,1)
	return:$$$ISERR(st) st
	return:'$IsObject(obj) $$$ERROR($$$ArgumentIsNotAnObject,"Body")

	set %request.Content = obj // obj here is a valid UTF8 proxyObject with required property
	return $$$OK
}

/// Get Origin from %request object 
ClassMethod GetOrigins() As %String
{
	set url = %request.GetCgiEnv("HTTP_REFERER")
	return $p(url,"/",1,3) // get http(s)://origin.com:port
}

/// Called for a REST page in the event of a login being required
ClassMethod Login(skipheader As %Boolean = 1) As %Status
{
	Do %response.SetHeader("Access-Control-Allow-Origin",..GetOrigins())
	Do %response.SetHeader("Access-Control-Allow-Credentials","true")
	Do %response.SetHeader("Access-Control-Allow-Methods","GET, PUT, POST, DELETE, OPTIONS")
	Do %response.SetHeader("Access-Control-Max-Age","10000")
	Do %response.SetHeader("Access-Control-Allow-Headers","Content-Type, Authorization, Accept-Language, X-Requested-With")

	Set %response.CharSet = "utf-8"
	Set %response.ContentType = "application/json"

	If (%request.GetCgiEnv("REQUEST_METHOD") = "OPTIONS"){
		Do %response.WriteHTTPHeader()
		Return $$$OK
	}
	Set %response.Status = "401 Unauthorized"

	#; Don't want the session token
	Set %response.OutputSessionToken = 0

	#; We don't want Basic authentication usually
	Do:$$$Debug %response.SetHeader("WWW-Authenticate","Basic")

	#; We need to manually write out the headers here because PAGE has not been called
	Do %response.WriteHTTPHeader()

	Return $$$OK
}

/// Issue an '500' error and give some indication as to what occurred.<br>
/// <b>pStatus</b> - %status, not %Exception.AbstractException.
ClassMethod Http500(pStatus As %Exception.AbstractException) As %Status
{
	// we are expecting status
	#; Set the response Http status
	Set %response.Status="500 Internal Server Error"
	
	#; Skip duplicate calls 
	Quit:$isObject(pStatus) $$$OK
	
	#; Return a helpful error string
	Write "{""Error"":"_$$$ZENJSSTR($System.Status.GetErrorText(pStatus,%session.Language))_"}"

	Quit $$$OK
}

/// Returns info about MDX4JSON package mapping
ClassMethod GetMappings() As %ArrayOfObjects
{
	Set result = ##class(%ArrayOfObjects).%New()
	Set mapped = ##class(%ListOfDataTypes).%New()
	Set unmapped = ##class(%ListOfDataTypes).%New()
	Set st = ##class(%CSP.Portal.Utils).%GetNamespaceList(.nslist)
	If $$$ISERR(st) Quit st
	Set namespace = $O(nslist(""))
	While namespace '= "" {
		Set enabled = $lg(nslist(namespace),1)
		If enabled = 1 {
			Set st = ..CheckNamespace(namespace)
			if $$$ISOK(st) {
				do mapped.Insert(namespace)
			} else {
				do unmapped.Insert(namespace)
			}
		}
		Set namespace = $O(nslist(namespace))
	}
	do result.SetAt(mapped,"Mapped")
	do result.SetAt(unmapped,"Unmapped")
	return result
}

/// Returns OK if namespace both exists and contains MDX4JSON package.<br>
/// <b>Namespace</b> - name of namespace. Sets namespace variable to current namespace if empty or missing.
ClassMethod CheckNamespace(ByRef Namespace As %String = {$Namespace}) As %Status
{
	if (Namespace = "") {
		set Namespace = $Namespace
		return $$$OK
	}

	return:('##class(%SYS.Namespace).Exists(Namespace)) $$$ERROR($$$NamespaceUnavailable, Namespace)
	new $Namespace
	set $Namespace = Namespace
	
	set class = "MDX4JSON.Utils"
	
	set exists = ##class(%Dictionary.CompiledClass).%ExistsId(class)
	return:(exists=$$$NO) $$$ERROR($$$GeneralError, "MDX4JSON package is not mapped to " _ Namespace)
	
	// If the current namespace holds unmapped MDX4JSON, include it regardless of dashboards existence
	return:(##class(%RoutineMgr).IsMapped(class _ ".cls") = $$$NO) $$$OK
	
	// Strictly speaking this can be a false-positive check
	set exists = ($data(@##class(MDX4JSON.DashboardRS).#global)>0)
	return:(exists=$$$NO) $$$ERROR($$$GeneralError, "No dashboards exist in " _ Namespace)

	return $$$OK
}

/// Executes actions and returns device output <br>
/// pObj - OREF or class<br>
/// pMethod - instance or class method to execute respectively<br>
/// pArgs - additional arguments
ClassMethod OutputToStr(pObj, pMethod, pArgs...) As %String [ ProcedureBlock = 0 ]
{
	set tOldIORedirected = ##class(%Device).ReDirectIO()
	set tOldMnemonic = ##class(%Device).GetMnemonicRoutine()
	set tOldIO = $io
	try {
		set str=""

		//Redirect IO to the current routine - makes use of the labels defined below
		use $io::("^"_$ZNAME)

		//Enable redirection
		do ##class(%Device).ReDirectIO(1)

		if $isobject(pObj) {
			do $Method(pObj,pMethod,pArgs...)
		} elseif $$$comClassDefined(pObj) {
			do $ClassMethod(pObj,pMethod,pArgs...)
		}
	} catch ex {
		set str = ""
	}

	//Return to original redirection/mnemonic routine settings
	if (tOldMnemonic '= "") {
		use tOldIO::("^"_tOldMnemonic)
	} else {
		use tOldIO
	}
	do ##class(%Device).ReDirectIO(tOldIORedirected)

	quit str

	//Labels that allow for IO redirection
	//Read Character - we don't care about reading
rchr(c)      quit
	//Read a string - we don't care about reading
rstr(sz,to)  quit
	//Write a character - call the output label
wchr(s)      do output($char(s))  quit
	//Write a form feed - call the output label
wff()        do output($char(12))  quit
	//Write a newline - call the output label
wnl()        do output($char(13,10))  quit
	//Write a string - call the output label
wstr(s)      do output(s)  quit
	//Write a tab - call the output label
wtab(s)      do output($char(9))  quit
	//Output label - this is where you would handle what you actually want to do.
	//  in our case, we want to write to str
output(s)    set str=str_s   quit
}

}
