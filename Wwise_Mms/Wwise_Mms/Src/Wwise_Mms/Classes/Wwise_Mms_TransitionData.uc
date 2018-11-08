//---------------------------------------------------------------------------------------
//	FILE:		Wwise_Mms_TransitionData.uc
//	AUTHOR:		Adrian Hall -- 2018
//	PURPOSE:	A rather hackey way to share information between sound managers
//---------------------------------------------------------------------------------------

class Wwise_Mms_TransitionData extends UIScreenListener;

var string postTransitionEvent;
var string postTransitionSecondaryEvent;
var string postTransitionDefinitionID;
var AkBank transitionBank;

event OnInit(UIScreen Screen){

	//This is unclean. I would love to replace it.
	Wwise_Mms_XComStrategySoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).soundManagerMessenger = self;
	Wwise_Mms_XComTacticalSoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).soundManagerMessenger = self;
	
}

function ResetValues(){

	postTransitionEvent = "";
	postTransitionDefinitionID = "";
	postTransitionSecondaryEvent = "";
	transitionBank = none;
}
