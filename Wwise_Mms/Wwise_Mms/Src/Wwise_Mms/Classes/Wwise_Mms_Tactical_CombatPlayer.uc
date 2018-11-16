//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_XComTacticalTrackPlayer.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles a tactical music with a possible sting
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

	//----------------------------------------------------------------------------------------------------------------------------Playing - StopMusic
	function StopMusic(optional bool bSkipSting){																`log("MMS Tactical Stop Music command intercepted.");}

	//----------------------------------------------------------------------------------------------------------------------------Playing - WwiseMms_StopMusic
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

	//----------------------------------------------------------------------------------------------------------------------------Playing - Begin
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

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_InitCombatPlayer
function WwiseMms_InitCombatPlayer(WwiseMms_TacticalMusicDefinition Def, bool xcom){

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
	if (Def.Com.ALoopCue != ""){
		wbHasAlienLoop = true;
		wiToLoad++;

		Mgr.RequestGameArchetype(Def.Com.ALoopCue, self, ALoopCueLoaded, true);
	}

	if (Def.Com.XSting != ""){
		wbHasXComSting = true;
		wiToLoad++;

		Mgr.RequestGameArchetype(Def.Com.XSting, self, XStingLoaded, true);
	}

	if (Def.Com.ASting != ""){
		wbHasAlienSting = true;
		wiToLoad++;

		Mgr.RequestGameArchetype(Def.Com.ASting, self, AStingLoaded, true);
	}
	
	Mgr.RequestGameArchetype(Def.Com.XLoopCue, self, XLoopCueLoaded, true);
	GotoState('Waiting');
	`log("Wwise Mms combat player initialized with" @Def.MusicID);
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_StopMusic
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

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_Play
function WwiseMms_Play(){

	wbPlaying = true;

	GotoState('Playing');
}

// xcom is true if it's the xcom turn and false if it's the alien turn
//----------------------------------------------------------------------------------------------------------------------------OnNotifyTurnChange
function OnNotifyTurnChange(bool xcom){

	if (!IsPlaying()){
		wbXComTurn = xcom;
		return;
	}

	// Transition from XCom to alien turn
	if (wbXComTurn && !xcom){
			if (wbHasAlienLoop){
				wXLoopAC.FadeOut(0.5f, 0.0f);
				wALoopAC.FadeIn(0.5f, 1.0f);
			}

		}else if(!wbXComTurn && xcom){

		// Transition from Alien to xcom
			if (wbHasAlienLoop){
				wALoopAC.FadeOut(0.5f, 0.0f);
				wXLoopAC.FadeIn(0.5f, 1.0f);
			}
	}

	wbXComTurn = xcom;
}

//----------------------------------------------------------------------------------------------------------------------------IsPlaying
function bool IsPlaying(){

	return wbPlaying;
}



//----------------------------------------------------------------------------------------------------------------------------MakeLoadProgress
private function MakeLoadProgress(){

	wiLoaded++;

	if (wiLoaded == wiToLoad){
		wbAllContentLoaded = true;
	}
}

//----------------------------------------------------------------------------------------------------------------------------XLoopCueLoaded
function XLoopCueLoaded(Object LoadedArchetype){

	wXLoopAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------ALoopCueLoaded
function ALoopCueLoaded(Object LoadedArchetype){

	wALoopAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------XStingLoaded
function XStingLoaded(Object LoadedArchetype){

	wXStingAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------AStingLoaded
function AStingLoaded(Object LoadedArchetype){

	wAStingAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}


//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
private function StartMusic(){														`log("MMS StartMusic intercepted.");}
function Play(){																	`log("MMS Play intercepted.");}
function StopMusic(optional bool bSkipSting){										`log("MMS StopMusic intercepted.");}


//----------------------------------------------------------------------------------------------------------------------------DefaultProperties
defaultproperties
{
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

