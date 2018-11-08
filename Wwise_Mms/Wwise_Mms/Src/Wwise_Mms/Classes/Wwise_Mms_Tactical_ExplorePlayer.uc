//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_XComTacticalExplorePlayer.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles explore music with intro
//
//	FILE:		Wwise_Mms_Tactical_ExplorePlayer.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Overrides original and provides additional mode and hooks for interactive music
//---------------------------------------------------------------------------------------

//Alternate private variables are indicated by a "w" prefix.
//Alternate functions and classes are indicated by a "WwiseMms_" Prefix

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

//----------------------------------------------------------------------------------------------------------------------------State - Waiting
auto state Waiting{}

//----------------------------------------------------------------------------------------------------------------------------State - Finished
state Finished{}

//----------------------------------------------------------------------------------------------------------------------------State - Playing
simulated state Playing{
	//----------------------------------------------------------------------------------------------------------------------------Playing - StopMusic
	function StopMusic(){`log("MMS explore stop command intercepted");}

	//----------------------------------------------------------------------------------------------------------------------------Playing - WwiseMms_StopMusic
	function WwiseMms_StopMusic()
	{
		wbPlaying = false;
		wIntroAC.FadeOut(2.0f, 0.0f);
		wExploreAC.FadeOut(2.0f, 0.0f);
		wDropshipAC.FadeOut(0.3f, 0.0f);

		`Log("Wwise Mms explore player music stopped.");
	}

	//----------------------------------------------------------------------------------------------------------------------------Playing - Begin
Begin:

	while(!wbAllContentLoaded){
		Sleep(0.1f);
	}

	`log("Wwise Mms -" @ "Explore Player Started" @ wDef.MusicID @ wbUseIntro ? "with an intro" : "");


	if(wbUseDropship){
		wbUseDropship = false;
		wDropshipAC.Play();
		Sleep(wDropshipAC.SoundCue.GetCueDuration());
	}

	if (wbUseIntro){
		wIntroAC.Play();
		Sleep(wDef.Exp.IntroLength);

		wExploreAC.Play();

		}else{

		wExploreAC.FadeIn(1.0f, 1.0f);
	}
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_Play
function WwiseMms_Play(){

	wbPlaying = true;

	GotoState('Playing');
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_StopMusic
function WwiseMms_StopMusic(){

	wbPlaying = false;

	wIntroAC.FadeOut(2.0f, 0.0f);
	wExploreAC.FadeOut(2.0f, 0.0f);
	wDropshipAC.FadeOut(0.3, 0.0f);
	GotoState('Finished');
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_InitExplorePlayer
function WwiseMms_InitExplorePlayer(WwiseMms_TacticalMusicDefinition _Def){

	local XComContentManager Mgr;

	wDef = _Def;
	wbPlaying = false;
	wbAllContentLoaded = false;
	wbUseIntro = false;
	wbUseDropship = false;
	wloaded = 0;
	wiToLoad = 1;

	Mgr = `CONTENT;

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

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_InitExplorePlayer
function WwiseMms_InitExplorePlayer_WithDropship(WwiseMms_TacticalMusicDefinition _Def, string pathToDropship){

	local XComContentManager Mgr;

	wDef = _Def;
	wbPlaying = false;
	wbAllContentLoaded = false;
	wbUseIntro = false;
	wbUseDropship = true;
	wloaded = 0;
	wiToLoad = 2;

	Mgr = `CONTENT;

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

//----------------------------------------------------------------------------------------------------------------------------ExploreCueLoaded
function ExploreCueLoaded(Object LoadedArchetype){

	wExploreAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------IntroCueLoaded
function IntroCueLoaded(Object LoadedArchetype){

	wIntroAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------IntroCueLoaded
function DropshipCueLoaded(Object LoadedArchetype){

	wDropshipAC.SoundCue = SoundCue(LoadedArchetype);

	MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------MakeLoadProgress
private function MakeLoadProgress(){

	wloaded++;

	if (wloaded >= wiToLoad){
		wbAllContentLoaded = true;
	}
}

//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
function Play(){														`log("MMS explore play command intercepted");}
function StopMusic(){													`log("MMS explore stop command intercepted");}
function InitExplorePlayer(ExploreMusic _Def){							`log("MMS InitExplorePlayer command intercepted");}

//----------------------------------------------------------------------------------------------------------------------------DefaultProperties
defaultproperties
{
	wbUseDropship = false;

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