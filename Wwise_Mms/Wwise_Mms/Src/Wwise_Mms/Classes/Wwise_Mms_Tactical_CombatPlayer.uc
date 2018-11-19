//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_XComTacticalTrackPlayer.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles tactical combat music with a possible sting
//
//	FILE:		Wwise_Mms_Tactical_CombatPlayer.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Replicates original behaviour using WwiseMms_ sound definition classes
//					and standardized code formatting.
//				Code logic is largely retained from MMS.
//				Like MMS, provides the option to change music between XCOM and Advent turns.	
//---------------------------------------------------------------------------------------

//	Private variables which serve the same purpose as those in MMS are indicated by a "w" prefix.
//	Functions which replace functions from MMS are indicated by a "WwiseMms_" Prefix.

class Wwise_Mms_Tactical_CombatPlayer extends MMS_Tactical_TrackPlayer dependson(Wwise_Mms_XComTacticalSoundManager);

var private bool wbPlaying;
var private bool wbXComTurn;
var private bool wbHasAlienLoop;
var private bool wbHasXComSting;
var private bool wbHasAlienSting;
var private bool wbAllContentLoaded;
var private int wiToLoad;
var private int wiLoaded;

var private WwiseMms_TacticalMusicDefinition wTacDef;

var private AudioComponent wXLoopAC;
var private AudioComponent wXStingAC;
var private AudioComponent wALoopAC;
var private AudioComponent wAStingAC;



//-------------------------------------------------------------------------------------------------------State - Waiting
//	This player does not have an active cue.
//---------------------------------------------------------------------------------------------
auto state Waiting{
}

//-------------------------------------------------------------------------------------------------------State - Finished
//	This player has faded out of a cue.
//---------------------------------------------------------------------------------------------
state Finished{
}

//-------------------------------------------------------------------------------------------------------State - Playing
//	This player is starting or currently playing a cue.
//---------------------------------------------------------------------------------------------
simulated state Playing{

	//-------------------------------------------------------------------------------------------------------Playing - StopMusic
	//	Disabled legacy function from MMS.
	//	Use WwiseMms_StopMusic instead.
	//---------------------------------------------------------------------------------------------
	function StopMusic(optional bool bSkipSting){
	
																												`log("MMS Tactical Stop Music command intercepted.");
	}

	//-------------------------------------------------------------------------------------------------------Playing - WwiseMms_StopMusic
	//	Stops this the currently playing track with a 2 second fadeout.
	//	Plays a short "sting" if one is part of the definition.
	//	Changes state to "Finished".
	//	The version of this function within the state may not be needed, removal has not been validated.
	//---------------------------------------------------------------------------------------------
	function WwiseMms_StopMusic(optional bool bSkipSting){

		wbPlaying = false;
		wXLoopAC.FadeOut(2.0f, 0.0f);
		wALoopAC.FadeOut(2.0f, 0.0f);

		if (!bSkipSting){
			if (wbXComTurn || !wbHasAlienSting){
				wXStingAC.Play();

			}else{
			
				wAStingAC.Play();
			}
		}	

		GotoState('Finished');
	}

	//-------------------------------------------------------------------------------------------------------Playing - Begin
	//	Called when the "Playing" state is first set.
	//	Waits until all content to be played is asynchronously loaded.
	//	Once content is loaded this function initiates playback of a different track depending on 
	//		whose turn it is.
	//	The track for XCOM's turn will always play if no track is defined for Advent's turn
	//---------------------------------------------------------------------------------------------
	Begin:

		while(!wbAllContentLoaded){
			Sleep(0.1f);
		}
																												`log("Wwise Mms -" @ "Combat Player Started" @ wTacDef.MusicID);
		if (wbXComTurn || !wbHasAlienLoop){
			wXLoopAC.Play();

		}else{

		wALoopAC.Play();
		}
}

//-------------------------------------------------------------------------------------------------------WwiseMms_InitCombatPlayer
//	Initiates loading of the loops and stings for the passed definition.
//	"xcom" should be true if it is currently XCOM's turn, false otherwise.
//	Changes state to "Waiting".
//---------------------------------------------------------------------------------------------
function WwiseMms_InitCombatPlayer(WwiseMms_TacticalMusicDefinition musicDefinitionToLoad, bool xcom){

	local XComContentManager Mgr;

	Mgr = `CONTENT;
	wbXComTurn = xcom;
	wbHasXComSting = false;
	wbHasAlienLoop = false;
	wbHasAlienSting = false;
	wbAllContentLoaded = false;
	wiLoaded = 0;
	wiToLoad = 1;

	wXLoopAC.ResetToDefaults();
	wALoopAC.ResetToDefaults();
	wXStingAC.ResetToDefaults();
	wAStingAC.ResetToDefaults();


	// Now stream in music
	if (musicDefinitionToLoad.Com.ALoopCue != ""){
		wbHasAlienLoop = true;
		wiToLoad++;

		Mgr.RequestGameArchetype(musicDefinitionToLoad.Com.ALoopCue, self, ALoopCueLoaded, true);
	}

	if (musicDefinitionToLoad.Com.XSting != ""){
		wbHasXComSting = true;
		wiToLoad++;

		Mgr.RequestGameArchetype(musicDefinitionToLoad.Com.XSting, self, XStingLoaded, true);
	}

	if (musicDefinitionToLoad.Com.ASting != ""){
		wbHasAlienSting = true;
		wiToLoad++;

		Mgr.RequestGameArchetype(musicDefinitionToLoad.Com.ASting, self, AStingLoaded, true);
	}
	
	Mgr.RequestGameArchetype(musicDefinitionToLoad.Com.XLoopCue, self, XLoopCueLoaded, true);
	GotoState('Waiting');
																												`log("Wwise Mms combat player initialized with" @Def.MusicID);
}

//-------------------------------------------------------------------------------------------------------WwiseMms_Play
//	Initiates playback of loaded music.
//	Changes state to "Playing".
//---------------------------------------------------------------------------------------------
function WwiseMms_Play(){

	wbPlaying = true;
	
	//	Actual playback logic is handled by the "Begin" function for the "Playing" state.
	GotoState('Playing');
}

//-------------------------------------------------------------------------------------------------------WwiseMms_StopMusic
//	Stops all playing tracks with a 2 second fadeout.
//	Plays a short "sting" depending on whose turn it is (if one is part of the definition).
//	Changes state to "Finished".
//---------------------------------------------------------------------------------------------
function WwiseMms_StopMusic(optional bool bSkipSting){

	wbPlaying = false;

	wXLoopAC.FadeOut(2.0f, 0.0f);
	wALoopAC.FadeOut(2.0f, 0.0f);

	if (!bSkipSting){
		if (wbXComTurn || !wbHasAlienSting){
			wXStingAC.Play();

			}else{

			wAStingAC.Play();
		}
	}	

	GotoState('Finished');
}

//-------------------------------------------------------------------------------------------------------XLoopCueLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the loop for XCOM's turn.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function XLoopCueLoaded(Object LoadedArchetype){

	wXLoopAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------ALoopCueLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the loop for Advent's turn.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function ALoopCueLoaded(Object LoadedArchetype){

	wALoopAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------XStingLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the sting for XCOM's turn.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function XStingLoaded(Object LoadedArchetype){

	wXStingAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------AStingLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the sting for Advent's turn.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function AStingLoaded(Object LoadedArchetype){

	wAStingAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------OnNotifyTurnChange
//	Notifies this object that the current turn has changed between XCOM and Advent.
//	xcom should be true if it is XCOM's turn and false if it is Advent's turn.
//	NOTE: Consider renaming this function to "NotifyOfTurnChange" or similar.
//---------------------------------------------------------------------------------------------
function OnNotifyTurnChange(bool xcom){

	if (!IsPlaying()){
		wbXComTurn = xcom;
		return;
	}

	// Transition from XCOM's turn music to Advent's.
	if (wbXComTurn && !xcom){
			if (wbHasAlienLoop){
				wXLoopAC.FadeOut(0.5f, 0.0f);
				wALoopAC.FadeIn(0.5f, 1.0f);
			}

		}else if(!wbXComTurn && xcom){

			// Transition from Advent's turn music to XCOM's.
			if (wbHasAlienLoop){
				wALoopAC.FadeOut(0.5f, 0.0f);
				wXLoopAC.FadeIn(0.5f, 1.0f);
			}
	}

	wbXComTurn = xcom;
}

//-------------------------------------------------------------------------------------------------------IsPlaying
//	Returns whether or not this player is currently playing a cue.
//---------------------------------------------------------------------------------------------
function bool IsPlaying(){

	//	Getter for private variable.
	return wbPlaying;
}


//-------------------------------------------------------------------------------------------------------MakeLoadProgress
//	Should be called only when this object has loaded a cue that it requested.
//	Increments wiLoaded to keep track of how many sound cues have been loaded.
//	Sets wbAllContentLoaded to true when wiLoaded equals wiToLoad.
//---------------------------------------------------------------------------------------------
private function MakeLoadProgress(){

	wiLoaded++;

	if (wiLoaded == wiToLoad){
		wbAllContentLoaded = true;
	}
}



//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
private function StartMusic(){														`log("MMS StartMusic intercepted.");}
function Play(){																	`log("MMS Play intercepted.");}
function StopMusic(optional bool bSkipSting){										`log("MMS StopMusic intercepted.");}


//----------------------------------------------------------------------------------------------------------------------------DefaultProperties
defaultproperties
{
	//Creates and stores a set of audio components for music playback.
	
	Begin Object Class=AudioComponent Name=wMusic01Comp
    End Object
	wXLoopAC=wMusic01Comp
	
	Begin Object Class=AudioComponent Name=wMusic02Comp
    End Object
	wXStingAC=wMusic02Comp

	Begin Object Class=AudioComponent Name=wMusic03Comp
    End Object
	wALoopAC=wMusic03Comp
	
	Begin Object Class=AudioComponent Name=wMusic04Comp
    End Object
	wAStingAC=wMusic04Comp

}

