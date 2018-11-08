//---------------------------------------------------------------------------------------
//	FILE:		Wwise_Mms_AkEventPlayer.uc
//	AUTHOR:		Adrian Hall -- 2018
//	PURPOSE:	Used to play AkEvents for all of Wwise Mms
//---------------------------------------------------------------------------------------

class Wwise_Mms_AkEventPlayer extends Actor;

var AkEvent endEvent;
var AkEvent currentEvent;
var XComContentManager Mgr;
var int lastPlayedID;
var array <name> myBankNames;
var array <AkBank> myBanks;

//----------------------------------------------------------------------------------------------------------------------------Init
function Init(){
	
	bUsePersistentSoundAkObject = true;
}

//----------------------------------------------------------------------------------------------------------------------------PlayEvent
function PlayEvent(AkEvent eventToPlay){

	local string pathToBank;
	
	//lastPlayedID = PlayAkSound(string(eventToPlay.Name));
	 
	currentEvent = eventToPlay;
	PlayAkEvent(eventToPlay);																	
	`Log("Wwise Mms attempting to play" @ eventToPlay);

	//`Log("Wwise Mms lastPlayedID =" @lastPlayedID);

	//SoundMenuMusic.Play_Main_Menu_Music

	//if(myBankNames.Find(eventToPlay.RequiredBank.name) == -1){
//
		//myBankNames.AddItem(eventToPlay.RequiredBank.name);
//
		//pathToBank = eventToPlay.RequiredBank.Outer.Name $ "." $ eventToPlay.RequiredBank.Name;
		//`CONTENT.RequestObjectAsync(pathToBank, self, OnNewBankLoaded);
//
		//`log("Wwise Mms requests bank" @pathToBank);
	//}

}

//----------------------------------------------------------------------------------------------------------------------------OnVeryWiseBankLoaded
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


//----------------------------------------------------------------------------------------------------------------------------StopMusic
function StopMusic(){

	if(endEvent == none){
		StopSounds();
		`log("Wwise Mms AkPlayer stopped without endEvent");

		return;
	}																		

	PlayAkEvent(endEvent);
	`log("Wwise Mms AkPlayer stopped with endEvent");
}

//----------------------------------------------------------------------------------------------------------------------------PlayMusicStartEventFromPath
function PlayMusicStartEventFromPath(string eventToPlayPath, optional string stopPath = ""){
						
	`Log("Wwise Mms loading" @ eventToPlayPath);

	if (stopPath != ""){
		endevent = AkEvent(`CONTENT.RequestGameArchetype(stopPath,,, false));	
	}
	`CONTENT.RequestObjectAsync(eventToPlayPath, self, OnEventLoaded, true);		

}

//----------------------------------------------------------------------------------------------------------------------------PlayNonstartMusicEventFromPath
function PlayNonstartMusicEventFromPath(string eventToPlayPath){

	`CONTENT.RequestGameArchetype(eventToPlayPath, self, OnEventLoaded, true);				
	`Log("Wwise Mms loading nonstart event called" @ eventToPlayPath);

}

//----------------------------------------------------------------------------------------------------------------------------OnEventLoaded
function OnEventLoaded(Object LoadedArchetype){

	local AkEvent eventToPlay;
	
	eventToPlay = AkEvent(LoadedArchetype);

	`Log("Wwise Mms successfully loaded" @ eventToPlay);

	PlayEvent(eventToPlay);		
													
}



defaultproperties
{
	bUsePersistentSoundAkObject = true
}