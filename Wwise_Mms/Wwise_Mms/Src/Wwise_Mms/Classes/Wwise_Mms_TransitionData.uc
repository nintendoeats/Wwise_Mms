//---------------------------------------------------------------------------------------
//	FILE:		Wwise_Mms_TransitionData.uc
//	AUTHOR:		Adrian Hall -- 2018
//	PURPOSE:	A persistent object for sharing transition data between the strategy
//					and tactical sound managers.
//---------------------------------------------------------------------------------------

//	UIScreenListener is extended because it survives all level transitions.
class Wwise_Mms_TransitionData extends UIScreenListener;

var string postTransitionEvent;
var string postTransitionSecondaryEvent;
var string postTransitionDefinitionID;
var AkBank transitionBank;

//-------------------------------------------------------------------------------------------------------Event - OnInit
//	Called whenever a UIScreen object is initialized.
//	Notifies whichever sound manager exists of this object's existence.
//---------------------------------------------------------------------------------------------
event OnInit(UIScreen Screen){

	//	This is not an efficient method of helping sound managers to locate the data object.
	// 	It has been retained because the problem is complex and this simple solution has so 
	//		little real overhead as not to be concerning.
	Wwise_Mms_XComStrategySoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).soundManagerMessenger = self;
	Wwise_Mms_XComTacticalSoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).soundManagerMessenger = self;
	
}

//-------------------------------------------------------------------------------------------------------ResetValues
//	Returns the message variables to an unpopulated state.
//---------------------------------------------------------------------------------------------
function ResetValues(){

	postTransitionEvent = "";
	postTransitionDefinitionID = "";
	postTransitionSecondaryEvent = "";
	transitionBank = none;
}
