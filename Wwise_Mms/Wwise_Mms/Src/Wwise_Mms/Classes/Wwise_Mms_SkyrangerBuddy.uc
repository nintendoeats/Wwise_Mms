//---------------------------------------------------------------------------------------
//  FILE:	    Wwise_Mms_SkyrangerBuddy.uc
//  AUTHOR:		Adrian Hall -- 2018
//  PURPOSE:	Listens for the launch button while on the way to a mission,
//					then optionally plays an event.
//---------------------------------------------------------------------------------------

class Wwise_Mms_SkyrangerBuddy extends Actor;

var string theEventPath;
var string loadingScreenPath;

var Wwise_Mms_AkEventPlayer thePlayer;

var bool loadedEventFired;

//-------------------------------------------------------------------------------------------------------Event - Tick
//	Called by the engine every frame.
//	Plays the AkEvent at theEventPath on the first frame in which the launch button is visible.
//---------------------------------------------------------------------------------------------
event Tick(float deltaTime){

	if(!loadedEventFired){																						
		if(theEventPath != "" && UIDropShipBriefing_MissionStart(class 'Object'.static.FindObject(loadingScreenPath, class 'UIDropShipBriefing_MissionStart')).LaunchButton.bIsVisible){
			thePlayer.PlayNonstartMusicEventFromPath(theEventPath);	
			loadedEventFired = true;																			`log("Wwise Mms detects tactical mission loading completed and fires the event" @theEventPath);
		}
	}
}

//-------------------------------------------------------------------------------------------------------SetValues
//	A simple variable setting function.
//---------------------------------------------------------------------------------------------
function SetValues(string path, string screen, Wwise_Mms_AkEventPlayer player){
	theEventPath = path;
	thePlayer = player;
	loadingScreenPath = screen;
	loadedEventFired = false;
}