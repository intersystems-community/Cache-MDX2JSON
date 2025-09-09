Class MDX2JSON.DashboardUtils Extends %DeepSee.Dashboard.Utils
{

/// Return list of possible filter member values for a given dashboard data source and filter.
/// This takes the form:<br/>
/// pMembers(n)=$LB(text,value,[description])<br/>
/// If <var>pSearchKey</var> is provided, then only return members that match the search key.
/// If <var>pRelatedFilters</var> is provided, it is an array of other filter values to use to
/// restrict the set of members. It takes the form:<br/>
/// pRelatedFilters(spec) = key<br/>
/// If <var>pCalcOnly</var> is true, then only return calculated members.<br/>
/// If <var>pRangeMode</var> is true, then only return members that are valid for range selection (used by searchBox).<br/>
/// If <var>pPreSelected</var> is a list of selected values; always display these items.<br/>
ClassMethod %GetMembersForFilter(pDataSource As %String, pFilter As %String, Output pMembers As %List, Output pDefaultValue As %String, pSearchKey As %String = "", ByRef pRelatedFilters, pCalcOnly As %Boolean = 0, pRangeMode As %Boolean = 0, ByRef pPreSelected As %String, MaxLen As %Integer = 1000) As %Status
{
	Set tSC = $$$OK
	Try {
		Kill pMembers
		Set pDefaultValue = ""
		Set pSearchKey = $$$UPPER(pSearchKey)

		// what kind of data source is in play?
		If (pDataSource="") Quit
		If (pDataSource'[".") {
  			Set pDataSource=pDataSource_".cube"
  		}
		Set tExt = $P(pDataSource,".",$L(pDataSource,"."))

		If (pRangeMode&&(tExt '= "pivot")&&(tExt'="cube")) {
			// range only works for cubes
			Quit
		}

		// DP-421530 - Fetch the type of the dimension
		Set tSC = ..%GetMemberDimensionType(pDataSource,pFilter,.tDimType)
		If $$$ISERR(tSC) Quit

		If ((tExt = "pivot")||(tExt = "cube")) {
			If (tExt = "pivot") {
				Set tPivot = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(pDataSource,.tSC)
				If '$IsObject(tPivot) Quit
				Set tCubeName = $$$UPPER(tPivot.%GetCubeName())
			}
			Else {
				Set tCubeName = $$$UPPER($P(pDataSource,".",1,$L(pDataSource,".")-1))
			}

			If (tCubeName = "") Quit

			If ($$$UPPER(pFilter)="MEASURES") {
				If ('pRangeMode) {
					/// Return the measures within the given cube as an array of form:<br/>
					/// pMeasures(n) = $LB(name,caption,type)
					Set tSC = ##class(%DeepSee.Utils).%GetCubeMeasures(tCubeName,.tMeasures)
					If $$$ISERR(tSC) Quit

					Set n = $O(tMeasures(""),1,tInfo)
					While (n'="") {
						Set pMembers($I(n)) = $LB($LG(tInfo,2),"["_$LG(tInfo,1)_"]")
						Set n = $O(tMeasures(n),1,tInfo)
					}
				}
			}
			ElseIf (pFilter="$NAMEDFILTER") {
				// JMD1253
				Set tSC = ##class(%DeepSee.Utils).%GetNamedFilters(tCubeName,.tNamedFilters)
				If $$$ISERR(tSC) {
					Set tSC = $$$OK
					Set pMembers($I(n)) = $LB($$$Text("Invalid named filter","%DeepSee"),"")
					Quit
				}
				Set k = $O(tNamedFilters(""))
				While (k'="") {
					Set tText = $LG(tNamedFilters(k),1)
					Set tSpec = $LG(tNamedFilters(k),3)
					If ((pSearchKey="")||($$$UPPER(tText)[pSearchKey)) {
						Set pMembers($I(n)) = $LB(tText,tSpec)
					}
					Set k = $O(tNamedFilters(k))
				}
			}
			ElseIf ($$$LOWER($E(pFilter,1,10))="$variable.") {
				// JMD1276
				Set tSC = ##class(%DeepSee.Utils).%GetPivotVariableValues(tCubeName,$P(pFilter,".",2),.tVariableValues)
				If $$$ISERR(tSC) {
					Set tSC = $$$OK
					Set pMembers($I(n)) = $LB($$$Text("Invalid pivot variable","%DeepSee"),"")
					Quit
				}
				Set k = $O(tVariableValues(""))
				While (k'="") {
					Set tText = $LG(tVariableValues(k),1)
					Set tSpec = $LG(tVariableValues(k),2)
					If ((pSearchKey="")||($$$UPPER(tText)[pSearchKey)) {
						Set pMembers($I(n)) = $LB(tText,tSpec)
					}
					Set k = $O(tVariableValues(k))
				}
			}
			Else {
				// DP-421530 - Reduce number of members fetch to 100
				Set tMaxMembers = MaxLen
				Set tContext = "filter"		// DTB599
				Set tMemberClass = ""
				Set tCalcMode = $S(pRangeMode:-1,pCalcOnly:1,1:0)
				Set tSC = ##class(%DeepSee.Utils).%GetDimensionMembers(tCubeName,pFilter,tContext,.tList,tMaxMembers,.tMemberClass,.pRelatedFilters,tCalcMode,pSearchKey)
				If $$$ISERR(tSC) {
					// DP-421530 - Log this as a application error and reset the status to allow the client to proceed
					D ##class(%DeepSee.Utils).%WriteToLog("Filter",$system.Status.GetOneErrorText(tSC))

					Set tSC = $$$OK
					Set pMembers($I(n)) = $LB($$$Text("Invalid filter","%DeepSee"),"")
					Quit
				}

				// PFS102 - Make a copy so we can delete nodes later to keep track of what has been included
				Merge tPreSelected = pPreSelected

				// special searching for computed dimensions
				If (('pRangeMode)&&('pCalcOnly)&&(tMemberClass'="")&&($zobjclassmethod(tMemberClass,"%IsA","%DeepSee.ComputedDimension.Base"))) {
					// Get info on the specified dimension
					Set tSC = ##class(%DeepSee.Utils).%GetDimensionInfo(tCubeName,pFilter,.tDimNo,.tHierNo,.tLevelNo,.tRelationName,.tRelationSpec)
					If $$$ISERR(tSC) Quit

					// dispatch to dimension class
					Set tDimObj = $zobjclassmethod(tMemberClass,"%Create",tCubeName,"",tDimNo,tHierNo,tLevelNo)
					If '$IsObject(tDimObj) {
						Set tSC = $$$ERROR($$$GeneralError,"Unable to create computed dimension object: " _ tMemberClass)
						Quit
					}
					Set tSC = tDimObj.%MemberSearch(pSearchKey,.pMembers)
					If $$$ISERR(tSC) Quit
					Quit
				}

				// split key into phrases!
				Set pSearchKey = $TR(pSearchKey,",-:","   ")
				For p = 1:1:$L(pSearchKey," ") {
					Set ph = $P(pSearchKey," ",p)
					Set:ph'="" tPhrase(ph) = ""
				}

				/// tList(n) = $LB(value,name,memberId,memberKey,[desc])<br/>
				Set k = $O(tList(""),1,tInfo)
				While (k'="") {
					Set tText = $LG(tInfo,2)
					Set tKey = $LG(tInfo,4)
					Set tDesc = $LG(tInfo,5)
					Set:tKey'="" tKey = "&["_$$$dsEscapeIdent(tKey)_"]"

					Set tSkip = 1
					If (pSearchKey="") {
						Set tSkip = 0
					}
					ElseIf ((tKey'="")&&$D(pPreSelected(tKey))) {
						// JMD1133: always list items in the pre-selected list
						Set tSkip = 0
					}
					Else {
						// if there is a search key, look for matching phrases in the text value
						Set tTest = $$$UPPER(tText)
						Set tTest = $TR(tTest,",-:()","     ")
						Set tTestD = $$$UPPER(tDesc)
						Set tTestD = $TR(tTestD,",-:()","     ")
						Set tSkip = 0
						Set ph = $O(tPhrase(""))
						While (ph'="") {
							Set match = 0
							For p = 1:1:$L(tTest," ") {
								Set t = $P(tTest," ",p)
								// JMD960: remove exact numeric match
								// If ($S($IsValidNum(ph):+t=+ph,1:(t[ph)) ) {
								If (t[ph) {
									Set match = 1
									Quit
								}
							}
							// also look in description
							If ('match && (tTestD'="")) {
								For p = 1:1:$L(tTestD," ") {
									Set t = $P(tTestD," ",p)
									If (t[ph) {
										Set match = 1
										Quit
									}
								}
								}
							If ('match) {
								Set tSkip = 1
								Quit
							}
							Set ph = $O(tPhrase(ph))
						}
					}

					If ('tSkip) {
						Set pMembers($I(n)) = $LB(tText,tKey,tDesc)
						Kill tPreSelected(tKey)
					}
					Set k = $O(tList(k),1,tInfo)
				}

				// PFS102 - If all seleted members have not been included already, add them
				If $D(tPreSelected) && (pSearchKey="") {
					Set k = $O(tPreSelected(""))
					While k'="" {
						Set tSearch = k
						If $E(tSearch,1,2)="&[" {
							Set tSearch = $E(tSearch,3,*-1)
						}
						Set tSC = ##class(MDX2JSON.DashboardUtils).%GetMembersForFilter(pDataSource,pFilter,.tMembers,.pDefaultValue,tSearch,.pRelatedFilters,pCalcOnly,pRangeMode, MaxLen)

						Set tMbr = $O(tMembers(""))
						While tMbr'="" {
							If $LG(tMembers(tMbr),2) = k {
								Set pMembers($I(n)) = tMembers(tMbr)
							}
							Set tMbr = $O(tMembers(tMbr))
						}
						Set k = $O(tPreSelected(k))
					}
				}

				If ((tDimType'="day")&&($G(n)>=tMaxMembers)) {
					// DP-421530 - Add a final item that is a message encouraging use of the search option
					Set pMembers($I(n)) = $LB($$$Text("More options exist","%DeepSee"),"$msg",$$$Text("Use Search to narrow results","%DeepSee"))
				}
			}
		}
		ElseIf (tExt = "kpi") {
			If ('pCalcOnly) {
				Set tName = $P(pDataSource,".",1,$L(pDataSource,".")-1)
				Set tKPIClass = ##class(%DeepSee.Utils).%GetKPIClass(tName)
				If (tKPIClass'="") {
					// JMD900 pass along related filters
					Set tSC = $zobjclassmethod(tKPIClass,"%GetFilterMembers",pFilter,.pMembers,.pDefaultValue,pSearchKey,pDataSource,.pRelatedFilters)
					If $$$ISERR(tSC) Quit
				}
			}
		}
		ElseIf (tExt = "worksheet") {
			If ('pCalcOnly) {
				Set tKPIClass = "%DeepSee.KPIWorksheet"
				Set tSC = $zobjclassmethod(tKPIClass,"%GetFilterMembers",pFilter,.pMembers,.pDefaultValue,pSearchKey,pDataSource)
				If $$$ISERR(tSC) Quit
			}
		}
		ElseIf (tExt = "metric") {
			If ('pCalcOnly) {
				Set tKPIClass = "Ens.BusinessMetricKPI"
				Set tSC = $zobjclassmethod(tKPIClass,"%GetFilterMembers",pFilter,.pMembers,.pDefaultValue,pSearchKey,pDataSource)
				If $$$ISERR(tSC) Quit
			}
		}
		Else {
			Quit
		}
	}
	Catch(ex) {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}
