//---------------------------------------------------------------------------------------
//	FILE:		Wwise_Mms_AkEventPlayer.uc
//	AUTHOR:		Adrian Hall -- 2018
//	PURPOSE:	Instantiated to play AkEvents for Wwise Mms
//---------------------------------------------------------------------------------------

class Wwise_Mms_AkEventPlayer extends Actor;

var AkEvent endEvent;
var AkEvent currentEvent;

var XComContentManager Mgr;

var int lastPlayedID;

var array <name> myBankNames;
var array <AkBank> myBanks;

//-------------------------------------------------------------------------------------------------------Init
//	Called when object is instantiated
//---------------------------------------------------------------------------------------------
function Init(){
	
	//	Forcing this setting may prevent music from stopping before a level transition.
	bUsePersistentSoundAkObject = true;
}

//-------------------------------------------------------------------------------------------------------PlayMusicStartEventFromPath
//	Initiates asynchronous loading and execution of a music event which starts a music definition.
//	Optionally initiates the asynchronous loading of a music stop event to be used later.
//---------------------------------------------------------------------------------------------
function PlayMusicStartEventFromPath(string eventToPlayPath, optional string stopPath = ""){
						
																													`log("Wwise Mms loading start event called" @ eventToPlayPath);
	if (stopPath != ""){
		endevent = AkEvent(`CONTENT.RequestGameArchetype(stopPath,,, false));	
	}
	`CONTENT.RequestObjectAsync(eventToPlayPath, self, OnEventLoaded, true);		
}

//-------------------------------------------------------------------------------------------------------PlayNonstartMusicEventFromPath
//	Initiates asynchronous loading and execution of a music event which is not from a new music definition.
//	At one point this function was more significantly differentiated from PlayMusicStartEventFromPath.
//	The two have been kept seperate in case the difference is needed for new behaviour.
//---------------------------------------------------------------------------------------------
function PlayNonstartMusicEventFromPath(string eventToPlayPath){

	`CONTENT.RequestGameArchetype(eventToPlayPath, self, OnEventLoaded, true);										`log("Wwise Mms loading nonstart event called" @ eventToPlayPath);
}

//-------------------------------------------------------------------------------------------------------StopMusic
//	Calls the AkEvent stored in endEvent.
//	If there is no endEvent, all sound on the object is stopped immediately.
//---------------------------------------------------------------------------------------------
function StopMusic(){

	if(endEvent == none){
		StopSounds();																								`log("Wwise Mms AkPlayer stopped without endEvent");
		return;
	}																		

	PlayEvent(endEvent);																							`log("Wwise Mms AkPlayer stopped with endEvent");
}

//-------------------------------------------------------------------------------------------------------OnEventLoaded
//	Function to be called when an AkEvent has been asynchronously loaded.
//---------------------------------------------------------------------------------------------
function OnEventLoaded(Object LoadedArchetype){

	local AkEvent eventToPlay;
	
	eventToPlay = AkEvent(LoadedArchetype);																			`log("Wwise Mms successfully loaded" @ eventToPlay);
	PlayEvent(eventToPlay);														
}

//-------------------------------------------------------------------------------------------------------PlayEvent
//	Calls an AkEvent on this object.
//	PlayEvent should never be called from outside this object, use the play music objects instead.
//	PlayAkEvent should never be called directly from outside this function.
//---------------------------------------------------------------------------------------------
function PlayEvent(AkEvent eventToPlay){

	currentEvent = eventToPlay;
	PlayAkEvent(eventToPlay);																						`log("Wwise Mms attempting to play" @ eventToPlay);
}

//-------------------------------------------------------------------------------------------------------OnNewBankLoaded
//	Function to be called when a sound bank has been asynchronously loaded.
//	Part of failed system attempting to resolve issue where engine failed to respond to some Wwise events.
//---------------------------------------------------------------------------------------------
function OnNewBankLoaded(object LoadedArchetype)
{
	local AkBank LoadedBank;

	LoadedBank = AkBank(LoadedArchetype);
	if (LoadedBank != none)
	{		
		myBanks.AddItem(LoadedBank);
		`log("Wwise Mms loaded bank" @LoadedBank.name);
	}
}




defaultproperties
{
	bUsePersistentSoundAkObject = true
}