/// MDX4JSON version
Class MDX4JSON.EmptyPortlet Extends %DeepSee.Component.Portlet.abstractPortlet
{

Parameter USECOMMONDIRECTORY = 1;

ClassMethod %OnGetPortletName() As %String
{
	quit "Empty portlet"
}

ClassMethod %OnGetPortletIcon() As %String
{
	quit "deepsee/window_24.png"
}

}
