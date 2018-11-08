//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_UISL_UIDropShipBriefing_MissionStart
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Plays a soundtrack on the dropship to a mission.
//
//	FILE:		Wwise_Mms_UISL_UIDropShipBriefing_MissionStart
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Looks for an Ak transition from strategy first, then for an akevent to tactical
//---------------------------------------------------------------------------------------

//Alternate private variables are indicated by a "w" prefix.
//Alternate functions and classes are indicated by a "WwiseMms_" Prefix
//The list of Skyranger music definitions is called WiserSkyrangerCues to make the difference more obvious in configs

class Wwise_Mms_UISL_UIDropShipBriefing_MissionStart extends MMS_UISL_UIDropShipBriefing_MissionStart 
dependson(Wwise_Mms_XComStrategySoundManager) 
dependson(Wwise_Mms_SkyrangerBuddy)
config(SkyrangerSound) 
config(WiseSound);

struct WwiseMms_SkyrangerMusicDefinition{
	var name MusicID;
	var string CuePath;
	var string Append;
	var bool WwiseEnabled;

	var bool PlayForAllTimesOfDay;
	var bool PlayForAllEnvironments;
	var bool PlayForAllBiomes;
	var bool PlayForAllMissions;

	var array<NameAndPath> Biome_EventPaths;
	var array<NameAndPath> Environment_EventPaths;
	var array<NameAndPath> Mission_EventPaths;
	var array<NameAndPath> TimeOfDay_EventPaths;

	var string Start_EventPath;
	var string TacticalDefinition_MusicID;
	var string TacticalDropship_EventPath;
	var string TacticalStart_EventPath;
	var string LaunchButton_EventPath;
	var string Stop_EventPath;

	structdefaultproperties
	{
		PlayForallMissions = true;
		WwiseEnabled = true;
		PlayForAllTimesOfDay = true;
		PlayForAllEnvironments = true;
		PlayForAllBiomes = true;
	}
};

var WwiseMms_TacticalMusicDefinition newTacticalMusicDefinition;
var Wwise_Mms_TransitionData soundManagerMessenger;
var string eventPlayerPath;

var config array<WwiseMms_SkyrangerMusicDefinition> WiserSkyrangerCues;
var array<WwiseMms_SkyrangerMusicDefinition> CompleteMusicDefs;
var float currentDefinitionTimer;

var WwiseMms_SkyrangerMusicDefinition activeMusicDefinition;

var string loadingScreenPath;
var bool loadedEventFired;
var bool active;

//----------------------------------------------------------------------------------------------------------------------------event - OnInit
event OnInit(UIScreen Screen){

	
	if(SoundManagerMessenger == none){
		soundManagerMessenger = Wwise_Mms_XComStrategySoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).soundManagerMessenger;
	}

	if (UIDropShipBriefing_MissionStart(Screen) != none){ //Ok, time for action...

		soundManagerMessenger.ResetValues();
		loadingScreenPath = PathName(Screen);
		activeMusicDefinition = GetRandomSkyrangerMusicDefinition();

		if(activeMusicDefinition.WwiseEnabled){

			`log("Wwise Mms plays Wwise Skyranger Music");
			ObtainEventPlayer().PlayMusicStartEventFromPath(activeMusicDefinition.Append $ activeMusicDefinition.Start_EventPath, activeMusicDefinition.Stop_EventPath);

			if(activeMusicDefinition.LaunchButton_EventPath != ""){
				class'Engine'.static.GetCurrentWorldInfo().Spawn(class'Wwise_Mms_SkyrangerBuddy').SetValues(activeMusicDefinition.Append $ activeMusicDefinition.LaunchButton_EventPath,loadingScreenPath,ObtainEventPlayer());
			}

		}else{	

			`log("Wwise Mms plays MMS Skyranger Music");
			AC = new class'AudioComponent';
			AC.SoundCue = SoundCue(DynamicLoadObject(activeMusicDefinition.CuePath, class'SoundCue'));
			AC.Play();
		}

		ObtainEventPlayer().SetRTPCValue('turnsRemaining',50);
	}
}

//----------------------------------------------------------------------------------------------------------------------------Event - OnRemoved
event OnRemoved(UIScreen Screen){

	local AkEvent bankEvent;
	local string pathToBank;

	if (UIDropShipBriefing_MissionStart(Screen) != none){
		
		active = false;

		if(activeMusicDefinition.WwiseEnabled){
			soundManagerMessenger.postTransitionDefinitionID = activeMusicDefinition.TacticalDefinition_MusicID;
			soundManagerMessenger.postTransitionEvent = activeMusicDefinition.TacticalDropship_EventPath;
			soundManagerMessenger.postTransitionSecondaryEvent = activeMusicDefinition.TacticalStart_EventPath;
			//XCom has its own way of stopping this event which is very nice.

			//Loading this bank into the transition manager partially resolves an issue with music stopping after the skyranger
			bankEvent = AkEvent(`CONTENT.RequestGameArchetype(activeMusicDefinition.Append $ activeMusicDefinition.Start_EventPath,,,false));
			pathToBank = bankEvent.RequiredBank.Outer.Name $ "." $ bankEvent.RequiredBank.Name;
			soundManagerMessenger.transitionBank = AkBank(`CONTENT.RequestGameArchetype(pathToBank,,,false));
			`log("Wwise Mms loads bank to transition:" @pathToBank);

		}else{
			AC.FadeOut(3.0f, 0.0f);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------------CreateNewSkyrangerMusicDefinitionFromCueName
function WwiseMms_SkyrangerMusicDefinition CreateNewSkyrangerMusicDefinitionFromCueName(string CueName){

	local WwiseMms_SkyrangerMusicDefinition newDef;

	newDef.CuePath = CueName;
	newDef.WwiseEnabled = false;

	return newDef;
}

//----------------------------------------------------------------------------------------------------------------------------CompileFullSkyrangerDefinitionList
function array<WwiseMms_SkyrangerMusicDefinition> CompileFullSkyrangerDefinitionList(){

	//Basically, this builds from the configs. If there is nothing in the configs, it starts looking for squad select and decides whether or not to use fallback.

	local array<WwiseMms_SkyrangerMusicDefinition> newList;
	local string str;
	local MusicDefinition Def; //Old style iterator for when we need to find a squadselect
	local bool nonFallbackDefinitionFound;

	newList = WiserSkyrangerCues;

	if (SkyrangerCues.Length > 0){
		foreach SkyrangerCues(str){
			newList.AddItem(CreateNewSkyrangerMusicDefinitionFromCueName(str));
		}
	}

	if(newList.Length < 1 && newList[0].MusicID == ''){																														//If no skyranger cues have been assigned...
	
		nonFallbackDefinitionFound = false;
		`log("Wwise Mms finds no specific skyranger cues and starts looking for squad select instead.");

		foreach class'Wwise_Mms_XComStrategySoundManager'.default.MusicDefs(Def){																							//For each music definition...
			if (Def.Group == eSSG_SquadSelect && class'Wwise_Mms_XComStrategySoundManager'.default.FallbackIDs.Find(Def.MusicID) == INDEX_NONE){							// ...if it is for squad select and isn't one of the fallback songs...
				nonFallbackDefinitionFound = true;																															//...then we have a cue to play that isn't fallback
				break;															//The search for squad select applies only to standard MMS definitions. Aside from being complicated, allowing Wwise Mms definitions in here might lead to problems.
			}
		}

		//We now know whether or not there is a nonfallback cue to play.

		foreach class'Wwise_Mms_XComStrategySoundManager'.default.MusicDefs(Def){																							//For each music definition...
			if (Def.Group == weSSG_SquadSelect){																															//...if it is for squad select...
				if (nonFallbackDefinitionFound){																															//...if there is a non-fallback cue to play...
					if (class'MMS_UISL_MCM'.default.bAllowFallback && class'Wwise_Mms_XComStrategySoundManager'.default.FallbackIDs.Find(Def.MusicID) != INDEX_NONE){		//...if the player has allowed fallback and it is a fallback song...
						newList.AddItem(CreateNewSkyrangerMusicDefinitionFromCueName(Def.CuePath));																			//...make this fallback track an option
					}
					else if (class'Wwise_Mms_XComStrategySoundManager'.default.FallbackIDs.Find(Def.MusicID) == INDEX_NONE){												//...elseif it is NOt a fallback song...
						newList.AddItem(CreateNewSkyrangerMusicDefinitionFromCueName(Def.CuePath));																			//...make this nonfallback track an option
					}
				}else{																																						//...if all of the cues are fallback
					newList.AddItem(CreateNewSkyrangerMusicDefinitionFromCueName(Def.CuePath));																				//...then instead of all that we just add our whole list of squad select cues
				}
			}
		}
	}


	return newList; 
}

//----------------------------------------------------------------------------------------------------------------------------CompileFullSkyrangerDefinitionList
function WwiseMms_SkyrangerMusicDefinition GetRandomSkyrangerMusicDefinition(){
	
	local WwiseMms_SkyrangerMusicDefinition definitionToReturn;
	local WwiseMms_SkyrangerMusicDefinition iDefinition;
	local int i;
	local array<int> idxs;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_MissionSite MissionState;
	local XComGameState_BattleData BattleData;
	local XComTacticalMissionManager missionManager;


	local PlotDefinition PlotDef;
	local name biome;
	local name missionFamily;
	local name environment;
	

	missionManager = XComTacticalMissionManager(class'Engine'.static.GetEngine().GetTacticalMissionManager());
	BattleData = XComGameState_BattleData(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

	missionFamily = name(missionManager.ActiveMission.MissionFamily);
	if (missionFamily == ''){
		missionFamily = MissionState.GeneratedMission.Mission.MissionName;
	}

	biome = name(BattleData.MapData.Biome);
	PlotDef = `PARCELMGR.GetPlotDefinition(BattleData.MapData.PlotMapName);
	environment = name(PlotDef.strType);
	
	missionFamily = '';
	if (MissionState != none){
		missionFamily = MissionState.GetMissionSource().DataName;
	}
	if (MissionState != none && MissionState.GetMissionSource().CustomMusicSet != ''){
		missionFamily = MissionState.GetMissionSource().CustomMusicSet;
	}

	//Right, so now that we have all that...

	CompleteMusicDefs = CompileFullSkyrangerDefinitionList();

	foreach CompleteMusicDefs(iDefinition,i){
		if(iDefinition.WwiseEnabled){

			if(!((class'MMS_UISL_MCM'.default.bMixInIndifferent && iDefinition.PlayForAllMissions) ||  iDefinition.Mission_EventPaths.Find('theName',missionFamily) != -1)){
				continue;
			}
			if(!(iDefinition.PlayForAllBiomes || iDefinition.Biome_EventPaths.Find('theName',biome) != -1)){
				continue;
			}
			if(!(iDefinition.PlayForAllEnvironments || iDefinition.Environment_EventPaths.Find('theName',environment) != -1)){
				continue;
			}

			idxs.AddItem(i); 

		}else{
			idxs.AddItem(i);
		}
	}

	i = idxs[rand(idxs.Length)];

	definitionToReturn = CompleteMusicDefs[i];

	return definitionToReturn;
}

//----------------------------------------------------------------------------------------------------------------------------ObtainEventPlayer
function Wwise_Mms_AkEventPlayer ObtainEventPlayer(){

	local Wwise_Mms_AkEventPlayer playerSeek;

	playerSeek = Wwise_Mms_AkEventPlayer(class 'Object'.static.FindObject(eventPlayerPath, class 'Wwise_Mms_AkEventPlayer'));

	if (playerSeek != None){return playerSeek;}

	playerSeek = class'Helpers'.static.GetWorldInfo().Spawn(class'Wwise_Mms_AkEventPlayer');							`log("Wwise Mms Skyranger finds no event player! Creating...");

	eventPlayerPath = PathName(playerSeek);

	return playerSeek;
}