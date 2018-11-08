//---------------------------------------------------------------------------------------
//  FILE:	    Wwise_Mms_SkyrangerBuddy.uc
//  AUTHOR:		Adrian Hall -- 2018
//  PURPOSE:	Detects the launch button and plays an event. Um...thats it...
//---------------------------------------------------------------------------------------
class Wwise_Mms_SkyrangerBuddy extends Actor;

var string theEventPath;
var string loadingScreenPath;
var Wwise_Mms_AkEventPlayer thePlayer;
var bool loadedEventFired;

//----------------------------------------------------------------------------------------------------------------------------event - Tick
event Tick(float deltaTime){

	if(!loadedEventFired){
		`log("Wwise Mms detects tactical mission loading completed and fires the event" @theEventPath);
		loadedEventFired = true;

		if(theEventPath  != "" && UIDropShipBriefing_MissionStart(class 'Object'.static.FindObject(loadingScreenPath, class 'UIDropShipBriefing_MissionStart')).LaunchButton.bIsVisible){
			thePlayer.PlayNonstartMusicEventFromPath(theEventPath);	
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------------SetValues
function SetValues(string path, string screen, Wwise_Mms_AkEventPlayer player){
	theEventPath = path;
	thePlayer = player;
	loadingScreenPath = screen;
	loadedEventFired = false;
}