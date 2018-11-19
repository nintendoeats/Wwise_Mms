//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_Strategy_TrackPlayer.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles a music track with fade-in / fade-out using an AudioComponent
//
//	FILE:		Wwise_Mms_Strategy_TrackPlayer.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Replicates original behaviour using WwiseMms_ sound definition classes
//					and standardized code formatting.
//				Code logic is largely retained from MMS.
//				As in MMS, provides the option to play an intro clip before the main loop.
//				This player class is used for both the strategy mode and main menu.			
//---------------------------------------------------------------------------------------

//	Private variables which serve the same purpose as those in MMS are indicated by a "w" prefix.
//	Functions which replace functions from MMS are indicated by a "WwiseMms_" Prefix.

class Wwise_Mms_Strategy_TrackPlayer extends MMS_Strategy_TrackPlayer config(StrategySound) dependson(Wwise_Mms_XComStrategySoundManager);

var config float wFadeDuration;

var WwiseMms_StrategyMusicDefinition wDef;
var WwiseMms_ShellMusicDefinition wShellDef;

var AudioComponent wAC;
var AudioComponent wIntroAC;

var private bool wbPlaying;
var private int wiToLoad;
var private int wiLoaded;
var private bool wbPlayIntro;
var private bool wbAllContentLoaded;
var private bool playShell;

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
	//	Slight modification of base function within state.
	//	Probably not needed, removal has not been validated.
	//---------------------------------------------------------------------------------------------
	function StopMusic(){

		wbPlaying = false;
	
		//	Shell definitions never define a fadeout, so they are just stopped normally.
		if(playShell){
			wAC.Stop();
			wIntroAC.Stop();

		}else{

			wAC.FadeOut(wDef.dontFadeOut ? 0.0f : wFadeDuration, 0.0f);
			wIntroAC.FadeOut(wDef.dontFadeOut ? 0.0f : wFadeDuration, 0.0f);
		}
		
		GotoState('Finished');
	}

	//-------------------------------------------------------------------------------------------------------Playing - Begin
	//	Called when the "Playing" state is first set.
	//	Waits until all content to be played is asynchronously loaded.
	//	Once content is loadeed this function plays the intro, waits for the duration of that intro 
	//		and then starts the main loop.
	//---------------------------------------------------------------------------------------------
	Begin:

		while(!wbAllContentLoaded){
			Sleep(0.1f);
		}

		if (playShell){
			if (wbPlayIntro){
				wIntroAC.Play();
				Sleep(wShellDef.IntroLength);
				wAC.Play();

			}else{

				wAC.Play();
			}

		}else{

			if (wbPlayIntro){
				wIntroAC.FadeIn(wDef.dontFadeIn ? 0.0f : wFadeDuration, 1.0f);
				Sleep(Def.IntroLength);

				wAC.Play();

			}else{

				wAC.FadeIn(wDef.dontFadeIn ? 0.0f : wFadeDuration, 1.0f);
			}
		}	
}


//-------------------------------------------------------------------------------------------------------preBeginPlay
//	Called after a level loads but before the game logic has started.
//	Sets some variables on the AudioComponents.
//---------------------------------------------------------------------------------------------
function preBeginPlay(){
	
	wAC.bStopWhenOwnerDestroyed = true;
	wIntroAC.bStopWhenOwnerDestroyed = true;
	
	//	bIsMusic may or may not serve any purpose, but is set just in case it does.
	wAC.bIsMusic = true;
	wIntroAC.bIsMusic = true;
}

//-------------------------------------------------------------------------------------------------------WwiseMms_Shell_InitStrategyPlayer
//	Sets this object up to play a music definition for the main menu when Play() is called.
//	Changes state to "Waiting".
//---------------------------------------------------------------------------------------------
function WwiseMms_Shell_InitStrategyPlayer(WwiseMms_ShellMusicDefinition _Def){
	local XComContentManager Mgr;

	wShellDef = _Def;
	TrackID = wShellDef.MusicID;
	wiToLoad = 1;
	wiLoaded = 0;
	wbPlayIntro = false;
	playShell = true;
	wbPlaying = false;
	wbAllContentLoaded = false;

	Mgr = XComContentManager(class'Engine'.static.GetEngine().GetContentManager());

	wAC.ResetToDefaults();

	Mgr.RequestGameArchetype(wShellDef.StartCuePath, self, WwiseMms_StrategyCueLoaded, true);

	GotoState('Waiting');

																												`log("Wwise Mms Strategy Track player shell intited with" @ wShellDef.MusicID);
}

//-------------------------------------------------------------------------------------------------------WwiseMms_Normal_InitStrategyPlayer
//	Sets this object up to play a standard strategy music definition when Play() is called.
//	Changes state to "Waiting".
//---------------------------------------------------------------------------------------------
function WwiseMms_Normal_InitStrategyPlayer(WwiseMms_StrategyMusicDefinition _Def){

	local XComContentManager Mgr;

	wDef = _Def;
	TrackID = wDef.MusicID;
	wiToLoad = 1;
	wiLoaded = 0;
	wbPlayIntro = false;
	playShell = false;
	wbPlaying = false;
	wbAllContentLoaded = false;

	Mgr = XComContentManager(class'Engine'.static.GetEngine().GetContentManager());

	wAC.ResetToDefaults();

	if (wDef.IntroCue != ""){
		Mgr.RequestGameArchetype(wDef.IntroCue, self, WwiseMms_StrategyIntroLoaded, true);
		wbPlayIntro = true;
		wiToLoad++;
	}

	Mgr.RequestGameArchetype(wDef.CuePath, self, WwiseMms_StrategyCueLoaded, true);
	GotoState('Waiting');

																												`log("Wwise Mms Strategy Track player intited with" @ wDef.MusicID);
}

//-------------------------------------------------------------------------------------------------------WwiseMms_StrategyIntroLoaded
//	Called when a sound cue to be played as the intro has been asynchronously loaded.
//---------------------------------------------------------------------------------------------
function WwiseMms_StrategyIntroLoaded(Object LoadedArchetype){

	wIntroAC.SoundCue = SoundCue(LoadedArchetype);
	WwiseMms_MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------WwiseMms_StrategyCueLoaded
//	Called when a sound cue to be played as the main loop has been asynchronously loaded.
//---------------------------------------------------------------------------------------------
function WwiseMms_StrategyCueLoaded(Object LoadedArchetype){

	wAC.SoundCue = SoundCue(LoadedArchetype);
	WwiseMms_MakeLoadProgress();
}

//-------------------------------------------------------------------------------------------------------WwiseMms_MakeLoadProgress
//	Increments wiLoaded to keep track of how many sound cues have been loaded.
//	Sets wbAllContentLoaded to true when wiLoaded equals wiToLoad.
//---------------------------------------------------------------------------------------------
private function WwiseMms_MakeLoadProgress(){

	wiLoaded++;

	if (wiLoaded == wiToLoad){
		wbAllContentLoaded = true;
	}
}

//-------------------------------------------------------------------------------------------------------Play
//	Initiates playback of the loaded sound cue and intro.
//	Changes state to "Playing".
//---------------------------------------------------------------------------------------------
function Play(){

	wbPlaying = true;
	GotoState('Playing');
}

//-------------------------------------------------------------------------------------------------------StopMusic
//	Stops all music on this object, using a fadeout if one is defined by the definition.
//	Changes state to "Finished".
//---------------------------------------------------------------------------------------------
function StopMusic(){

	wbPlaying = false;

	if(playShell){
		wAC.Stop();
		wIntroAC.Stop();

	}else{
	
		wAC.FadeOut(wDef.dontFadeOut ? 0.0f : wFadeDuration, 0.0f);
		wIntroAC.FadeOut(wDef.dontFadeOut ? 0.0f : wFadeDuration, 0.0f);
	}

	wAC.ResetToDefaults();
	wIntroAC.ResetToDefaults();
	GotoState('Finished');
}

//-------------------------------------------------------------------------------------------------------IsPlaying
//	Returns whether or not this player is currently playing a cue.
//---------------------------------------------------------------------------------------------
function bool IsPlaying(){

	//	Public getter is required because this is a private variable.
	return wbPlaying;
}


//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
//function Play(){															`log("MMS Play intercepted.");}
//function StopMusic(){														`log("MMS StopMusic intercepted.");}
function InitStrategyPlayer(MusicDefinition _Def){							`log("MMS InitStrategyPlayer intercepted.");}
function StrategyCueLoaded(Object LoadedArchetype){							`log("MMS StrategyCueLoaded intercepted.");}
function StrategyIntroLoaded(Object LoadedArchetype){						`log("MMS StrategyIntroLoaded intercepted.");}
private function MakeLoadProgress(){										`log("MMS MakeLoadProgress intercepted.");}

//----------------------------------------------------------------------------------------------------------------------------DefaultProperties
defaultproperties
{
	playShell = false;

	Begin Object Class=AudioComponent Name=wMusic01Comp
    End Object
	wAC=wMusic01Comp

	Begin Object Class=AudioComponent Name=wMusic02Comp
    End Object
	wIntroAC=wMusic02Comp
}