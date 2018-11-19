//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_XComTacticalExplorePlayer.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles explore music with intro
//
//	FILE:		Wwise_Mms_Tactical_ExplorePlayer.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Replicates original behaviour using WwiseMms_ sound definition classes
//					and standardized code formatting.
//				Code logic is largely retained from MMS.
//---------------------------------------------------------------------------------------

//	Private variables which serve the same purpose as those in MMS are indicated by a "w" prefix.
//	Functions which replace functions from MMS are indicated by a "WwiseMms_" Prefix.

class Wwise_Mms_Tactical_ExplorePlayer extends MMS_Tactical_ExplorePlayer dependson(Wwise_Mms_XComTacticalSoundManager);

var private WwiseMms_TacticalMusicDefinition wDef;
var private AudioComponent wIntroAC;
var private AudioComponent wExploreAC;
var private AudioComponent wDropshipAC;
var private bool wbPlaying;
var private int wloaded;
var private int wiToLoad;
var private bool wbAllContentLoaded;
var private bool wbUseIntro;
var private bool wbUseDropship;

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
	function StopMusic(){
	
																												`log("MMS explore stop command intercepted");
	}

	//-------------------------------------------------------------------------------------------------------Playing - WwiseMms_StopMusic
	//	Stops this the currently playing track with a 2 second fadeout.
	//	Changes state to "Finished".
	//	The version of this function within the state may not be needed, removal has not been validated.
	//---------------------------------------------------------------------------------------------
	function WwiseMms_StopMusic()
	{
		wbPlaying = false;
		wIntroAC.FadeOut(2.0f, 0.0f);
		wExploreAC.FadeOut(2.0f, 0.0f);
		wDropshipAC.FadeOut(0.3f, 0.0f);
																												`log("Wwise Mms explore player music stopped.");
	}

	//-------------------------------------------------------------------------------------------------------Playing - Begin
	//	Called when the "Playing" state is first set.
	//	Waits until all content to be played is asynchronously loaded.
	//	Once content is loaded this function initiates playback of the dropship cue (if used),
	//		followed by the intro cue (if used), followed by the main explore loop.
	//	If no intro is defined then a 1 second fade-in is applied to the loop.
	//---------------------------------------------------------------------------------------------
	Begin:

		while(!wbAllContentLoaded){
			Sleep(0.1f);
		}
		
		//	If there is a dropship cue we play it and wait a number of seconds equal to its length
		//		before moving on to the intro and main loop.
		if(wbUseDropship){
			wbUseDropship = false;
			wDropshipAC.Play();
			Sleep(wDropshipAC.SoundCue.GetCueDuration());
		}

		//	If there is an intro we play it and wait a number of seconds equal to its length
		//		before starting the main loop.
		//	Otherwise we start playing the main loop immediately.
		if (wbUseIntro){
			wIntroAC.Play();
			Sleep(wDef.Exp.IntroLength);

			wExploreAC.Play();

			}else{

			wExploreAC.FadeIn(1.0f, 1.0f);
		}
}

//-------------------------------------------------------------------------------------------------------WwiseMms_InitExplorePlayer
//	Initiates loading of the intro and loop for the passed definition.
//	Changes state to "Waiting".
//---------------------------------------------------------------------------------------------
function WwiseMms_InitExplorePlayer(WwiseMms_TacticalMusicDefinition musicDefinitionToLoad){

	local XComContentManager Mgr;

	Mgr = `CONTENT;
	wDef = musicDefinitionToLoad;
	wbPlaying = false;
	wbAllContentLoaded = false;
	wbUseIntro = false;
	wbUseDropship = false;
	wloaded = 0;
	wiToLoad = 1;

	wExploreAC.ResetToDefaults();
	wIntroAC.ResetToDefaults();
	
	if (wDef.Exp.IntroCue != ""){
		wbUseIntro = true;
		wiToLoad++;
		Mgr.RequestGameArchetype(wDef.Exp.IntroCue, self, IntroCueLoaded, true);
	}

	Mgr.RequestGameArchetype(wDef.Exp.Cue, self, ExploreCueLoaded, true);
																											`log("Wwise Mms Explore Player inited.");
	GotoState('Waiting');
}

//-------------------------------------------------------------------------------------------------------WwiseMms_InitExplorePlayer
//	Initiates loading of the intro and loop and a dropship sound for the passed definition.
//	Changes state to "Waiting".
//---------------------------------------------------------------------------------------------
function WwiseMms_InitExplorePlayer_WithDropship(WwiseMms_TacticalMusicDefinition _Def, string pathToDropship){

	local XComContentManager Mgr;
	Mgr = `CONTENT;

	wDef = _Def;
	wbPlaying = false;
	wbAllContentLoaded = false;
	wbUseIntro = false;
	wbUseDropship = true;
	wloaded = 0;
	wiToLoad = 2;

	wExploreAC.ResetToDefaults();
	wIntroAC.ResetToDefaults();
	wDropshipAC.ResetToDefaults();
	
	if (wDef.Exp.IntroCue != ""){
		wbUseIntro = true;
		wiToLoad++;
		Mgr.RequestGameArchetype(wDef.Exp.IntroCue, self, IntroCueLoaded, true);
	}

	Mgr.RequestGameArchetype(wDef.Exp.Cue, self, ExploreCueLoaded, true);

	Mgr.RequestGameArchetype(pathToDropship, self, DropshipCueLoaded, true);
																											`log("Wwise Mms Explore Player inited with dropship.");
	GotoState('Waiting');
}

//-------------------------------------------------------------------------------------------------------ExploreCueLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the explore music loop.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function ExploreCueLoaded(Object LoadedArchetype){

	wExploreAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------IntroCueLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the explore music intro.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function IntroCueLoaded(Object LoadedArchetype){

	wIntroAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------IntroCueLoaded
//	Casts the loaded archetype as a sound cue and sets it up as the music played as the XCOM
//		"dropship" animation plays at level start.
//	Finishes by calling MakeLoadProgress.
//---------------------------------------------------------------------------------------------
function DropshipCueLoaded(Object LoadedArchetype){

	wDropshipAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------MakeLoadProgress
//	Should be called only when this object has loaded a cue that it requested.
//	Increments wiLoaded to keep track of how many sound cues have been loaded.
//	Sets wbAllContentLoaded to true when wiLoaded equals wiToLoad.
//---------------------------------------------------------------------------------------------
private function MakeLoadProgress(){

	wloaded++;

	if (wloaded >= wiToLoad){
		wbAllContentLoaded = true;
	}
}

//-------------------------------------------------------------------------------------------------------Playing - WwiseMms_StopMusic
//	Initiates playback of loaded music.
//	Changes state to "Playing".
//---------------------------------------------------------------------------------------------
function WwiseMms_Play(){

	wbPlaying = true;

	GotoState('Playing');
}

//-------------------------------------------------------------------------------------------------------WwiseMms_StopMusic
//	Stops all track with a 2 second fadeout (0.3 seconds for the dropship cue).
//	Changes state to "Finished".
//---------------------------------------------------------------------------------------------
function WwiseMms_StopMusic(){

	wbPlaying = false;

	wIntroAC.FadeOut(2.0f, 0.0f);
	wExploreAC.FadeOut(2.0f, 0.0f);
	wDropshipAC.FadeOut(0.3, 0.0f);
	
	GotoState('Finished');
}



//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
function Play(){														`log("MMS explore play command intercepted");}
function StopMusic(){													`log("MMS explore stop command intercepted");}
function InitExplorePlayer(ExploreMusic _Def){							`log("MMS InitExplorePlayer command intercepted");}

//----------------------------------------------------------------------------------------------------------------------------DefaultProperties
defaultproperties
{
	//	This disables the dropship sound for final release.
	wbUseDropship = false;

	//	Creates and stores a set of audio components for music playback.
	Begin Object Class=AudioComponent Name=wMusic01Comp
    End Object
	wExploreAC=wMusic01Comp

	Begin Object Class=AudioComponent Name=wMusic02Comp
    End Object
	wIntroAC=wMusic02Comp

	Begin Object Class=AudioComponent Name=wMusic03Comp
    End Object
	wDropshipAC=wMusic02Comp
}