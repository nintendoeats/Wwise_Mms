//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_Strategy_TrackPlayer.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles a music track with fade-in / fade-out using an AudioComponent
//
//	FILE:		Wwise_Mms_Strategy_TrackPlayer.uc
//	MODIFIED:	nintendoeats -- 2018
//	PURPOSE:	Overrides original and provides additional mode and hooks for interactive music
//---------------------------------------------------------------------------------------
//Alternate private variables are indicated by a "w" prefix.
//Alternate functions and classes are indicated by a "WwiseMms_" Prefix

class Wwise_Mms_Strategy_TrackPlayer extends MMS_Strategy_TrackPlayer config(StrategySound) dependson(Wwise_Mms_XComStrategySoundManager);

var bool disabledByCutscene;
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

//----------------------------------------------------------------------------------------------------------------------------State - Waiting
auto state Waiting{
}

//----------------------------------------------------------------------------------------------------------------------------State - Finished
state Finished{
}

//----------------------------------------------------------------------------------------------------------------------------State - Playing
simulated state Playing{

	//----------------------------------------------------------------------------------------------------------------------------Playing - StopMusic
	function StopMusic(){

		wbPlaying = false;
	
		if(playShell){
			wAC.Stop();
			wIntroAC.Stop();

		}else{

			wAC.FadeOut(wDef.dontFadeOut ? 0.0f : wFadeDuration, 0.0f);
			wIntroAC.FadeOut(wDef.dontFadeOut ? 0.0f : wFadeDuration, 0.0f);
		}
		
		GotoState('Finished');
	}

	//----------------------------------------------------------------------------------------------------------------------------Playing - Begin
	Begin:

		while(!wbAllContentLoaded){
			Sleep(0.1f);
		}

		if(disabledByCutscene){
			Stop;
		}

		if (playShell){
			if (wbPlayIntro){
				wIntroAC.Play();
				Sleep(wShellDef.IntroLength);
				wAC.Play();

			}else{

				if(disabledByCutscene){

					Stop;
				}

				wAC.Play();
			}

		}else{

			if (wbPlayIntro){
				wIntroAC.FadeIn(wDef.dontFadeIn ? 0.0f : wFadeDuration, 1.0f);
				Sleep(Def.IntroLength);

				if(disabledByCutscene){
					Stop;
				}

				wAC.Play();

			}else{

				wAC.FadeIn(wDef.dontFadeIn ? 0.0f : wFadeDuration, 1.0f);
			}
		}
}


//----------------------------------------------------------------------------------------------------------------------------State - Finished
function preBeginPlay(){
	wAC.bStopWhenOwnerDestroyed = true;
	wAC.bIsMusic = true;

	wIntroAC.bStopWhenOwnerDestroyed = true;
	wIntroAC.bIsMusic = true;
}


//----------------------------------------------------------------------------------------------------------------------------Play
function Play(){

	wbPlaying = true;
	GotoState('Playing');
}

//----------------------------------------------------------------------------------------------------------------------------StopMusic
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

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_Shell_InitStrategyPlayer
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

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_Normal_InitStrategyPlayer
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

//----------------------------------------------------------------------------------------------------------------------------IsPlaying
function bool IsPlaying(){

	return wbPlaying;
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_StrategyCueLoaded
function WwiseMms_StrategyCueLoaded(Object LoadedArchetype){

	wAC.SoundCue = SoundCue(LoadedArchetype);
	WwiseMms_MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_StrategyIntroLoaded
function WwiseMms_StrategyIntroLoaded(Object LoadedArchetype){

	wIntroAC.SoundCue = SoundCue(LoadedArchetype);
	WwiseMms_MakeLoadProgress();
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_MakeLoadProgress
private function WwiseMms_MakeLoadProgress(){

	wiLoaded++;

	if (wiLoaded == wiToLoad){
		wbAllContentLoaded = true;
	}
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
	disabledByCutscene = false;

	Begin Object Class=AudioComponent Name=wMusic01Comp
    End Object
	wAC=wMusic01Comp

	Begin Object Class=AudioComponent Name=wMusic02Comp
    End Object
	wIntroAC=wMusic02Comp
}