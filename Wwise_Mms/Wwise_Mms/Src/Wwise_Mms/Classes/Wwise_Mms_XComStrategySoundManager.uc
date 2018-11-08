//---------------------------------------------------------------------------------------
//  FILE:		MMS_XComStrategySoundManager.uc
//  AUTHOR:		E3245, robojumper --  2016
//  PURPOSE:	Completely replaces the wwise implementation in the strategy layer
//
//	FILE:		Wwise_Mms_XComStrategySoundManager.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Allows interactive music using AkEvents to be mixed in with standard MMS packs for Strategy
//---------------------------------------------------------------------------------------

//Alternate private variables are indicated by a "w" prefix.
//Alternate functions and classes are indicated by a "WwiseMms_" Prefix
//The list of Wwise Mms music definitions is called WiserStrategyMusicDefs to make the difference more obvious in configs

class Wwise_Mms_XComStrategySoundManager extends MMS_XComStrategySoundManager dependson(Wwise_Mms_TransitionData) config(StrategySound) config(WiseSound);
																		
enum WwiseMms_EStrategySoundGroup{
	weSSG_Chapter01, // for convenience
	weSSG_Chapter02, // all three will get migrated
	weSSG_Chapter03, // to the CustomObjective at startup!
	weSSG_CustomObjective, // main way of tracking certain stages of the game

	weSSG_Geoscape, // event will also check for the one below
	weSSG_GeoDoomClock, // if the doom clock is ticking. if not, will fall back to GeoScape

	weSSG_SquadSelect,
	weSSG_SquadSelectMission, // if it matches the current mission type, will get played. if not, fallback to SquadSelect

	weSSG_Credits, // credits music
	weSSG_Loss,

	weSSG_AfterActionFlawless,
	weSSG_AfterActionCasualties,
	weSSG_AfterActionLoss,

	//NEW
	weSSG_Skyranger
};

struct NameAndPath{
	var name theName;
	var string thePath;
};

struct WwiseMms_StrategyMusicDefinition{
	var name								MusicID;
	var string								CuePath;
	var string								IntroCue;
	var float								IntroLength;
	var bool								dontFadeIn;
	var bool 								dontFadeOut;
	var WwiseMms_EStrategySoundGroup		Group;
	var ObjectiveCategorization				Objective; // for eSSG_CustomObjective
	var name								MissionName; // for eSSG_SquadSelectMission
	
	//These variables are new for Wwise_Mms

	var bool								WwiseEnabled;
	var bool								isAssigned; //Used for detecting empty definitions.

	var int									Lifespan;
	var string								Append;

	var array<NameAndPath>					SquadSelectMission_EventPaths;
	var bool 								PlaySquadSelectForAllMissions;

	var string 								End_EventPath;

	var string 								DoomClock_StartEventPath;
	var string 								Geoscape_StartEventPath;
	var string 								HQChapter01_StartEventPath;
	var string 								HQChapter02_StartEventPath;
	var string 								HQChapter03_StartEventPath;
	var string 								SquadSelect_StartEventPath;
	var string 								WinCredits_StartEventPath;
	var string 								LoseCredits_StartEventPath;
	var string 								aaFlawless_StartEventPath;
	var string 								aaCasualties_StartEventPath;
	var string 								aaLoss_StartEventPath;
	var string 								Skyranger_StartEventPath;

	var string 								DoomClock_TransitionEventPath;
	var string 								Geoscape_TransitionEventPath;
	var string 								HQChapter01_TransitionEventPath;
	var string 								HQChapter02_TransitionEventPath;
	var string 								HQChapter03_TransitionEventPath;
	var string 								SquadSelect_TransitionEventPath;
	var string 								Skyranger_TransitionEventPath;

	//These are minor event options to be integrated. We should also do something with setting mission names for both this and tactical.
	var array<string>						DoomLevel_EventPaths;
	var array<string>						DeadSoldierCount_EventPaths;
	var array<string>						ContactedRegionCount_EventPaths;
	var array<string>						FacilityCount_EventPaths;

	var string								UnsupportedRoom_EventPath;
	var array<NameAndPath>					Room_EventPaths;

	var string								StartScanning_EventPath;
	var string								StopScanning_EventPath;
	var string								ScanningCompleted_EventPath;

	var string								StartFlying_EventPath;
	var string								StopFlying_EventPath;

	//var string PursuedByUFO_EventPath;//

	//var() bool bHasGoldenPathUFOAppeared; // Has a UFO spawned from a Golden Path mission yet (guaranteed one per game)
	//var() bool bHasPlayerBeenIntercepted; // Has the player been intercepted by a UFO
	//var() bool bHasPlayerAvoidedUFO; // Has the player avoided being hunted by a UFO
	//These are in AlienHQ. May allow UFO detection.


	structdefaultproperties
	{
		PlaySquadSelectForAllMissions = true;
		WwiseEnabled = true;
		isAssigned = false;
		Lifespan = 480;
	}
};

struct WwiseMms_ShellMusicDefinition{
	var name								MusicID;
	var string								StartCuePath;
	var string 								IntroCuePath;
	var float 								IntroLength;
	var string								Append;

	var string								Start_EventPath;
	var string 								Shell_EventPath;
	var string 								NewGame_EventPath;
	var string 								LoadGame_EventPath;
	var string 								Options_EventPath;
};



var array<name> ChapterOneIDs;
var array<name> ChapterTwoIDs;
var array<name> ChapterThreeIDs;
var array<name> FallbackIDs; //Replaces FallbackSongs for the sake of naming consistency for each manager. Builds partially from +FallbackSongs in the config.

var float currentDefinitionTimer;
var float updatePeriod;

var config string testNoiseEventPath;

var array<Wwise_Mms_Strategy_TrackPlayer> wPlayers;	//Since the cues need fading in/out, vanilla MMS has multiple ACs that will get used in order
var Wwise_Mms_AkEventPlayer eventPlayer;

var Wwise_Mms_StrategyBuddy myBuddy;

var Wwise_Mms_TransitionData soundManagerMessenger;

var config array<WwiseMms_StrategyMusicDefinition> WiserStrategyMusicDefs;
var array<WwiseMms_StrategyMusicDefinition> CompleteMusicDefs;			//Always read from this list!
var WwiseMms_StrategyMusicDefinition emptyMusicDefinition;	
var WwiseMms_StrategyMusicDefinition activeMusicDefinition;																							
var WwiseMms_StrategyMusicDefinition wLastLoadoutDef;					//For Dropship

var config array<string> VeryWiseSoundBankNames;
var array<AkBank> VeryWiseSoundBanks; 

var AkEvent nextEvent;


//----------------------------------------------------------------------------------------------------------------------------Tick
function Tick( float deltaTime){
	
	currentDefinitionTimer += deltaTime;
}

//----------------------------------------------------------------------------------------------------------------------------Event - PreBeginPlay
event PreBeginPlay(){

	local int idx;
	local XComContentManager ContentMgr;

	super.PreBeginPlay();

	ContentMgr = XComContentManager(class'Engine'.static.GetEngine().GetContentManager());

		// Load Banks
	for(idx = 0; idx < VeryWiseSoundBankNames.Length; idx++){
		//ContentMgr.RequestObjectAsync(VeryWiseSoundBankNames[idx], self, OnVeryWiseBankLoaded);
	}


	BeginStrategyBuddy();
	WwiseMms_RewriteConvenienceChapters();
}

//----------------------------------------------------------------------------------------------------------------------------OnVeryWiseBankLoaded
function OnVeryWiseBankLoaded(object LoadedArchetype)
{
	local AkBank LoadedBank;

	LoadedBank = AkBank(LoadedArchetype);
	if (LoadedBank != none)
	{		
		VeryWiseSoundBanks.AddItem(LoadedBank);
	}
}

//----------------------------------------------------------------------------------------------------------------------------BeginTacticalBuddy
function BeginStrategyBuddy(){

	if(myBuddy == none){
		myBuddy = Spawn(Class'Wwise_Mms_StrategyBuddy',self);
	}

	myBuddy.myBoss = self;
}

//----------------------------------------------------------------------------------------------------------------------------LoadEventFromPathSync
function AkEvent LoadEventFromPathSync(string append, string path){

	if(path != ""){
		return AkEvent(`CONTENT.RequestGameArchetype(append $ path,,,false));
	}

	return none;
}

//----------------------------------------------------------------------------------------------------------------------------PlayTestNoise
function PlayTestNoise(){

	ObtainEventPlayer().PlayNonstartMusicEventFromPath(testNoiseEventPath);
	`log("Wwise Mms test noise played.");
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------------------------------------------PlayBaseViewMusic
function PlayBaseViewMusic(){																									
	
	local WwiseMms_StrategyMusicDefinition newDefinitionToPlay;
	local AkEvent currentDefinitionTransitionEvent;
	local string currentDefinitionTransitionEventPath;
	local AkEvent newDefinitionStartEvent;
	local string newDefinitionStartEventPath;
	local int chapter;
	local int found;

	`log("Wwise Mms -- PlayBaseViewMusic called. LastCommand is" @LastCommand $ " and activeMusicDefinition is" @activeMusicDefinition.MusicID);

	if(LastCommand == "PlayBaseViewMusic"){ //Returns if Base View is already playing due to unfound intermediate tracks or being called by the buddy
		return;
	}

	chapter = CurrentChapterNumber();

	if(activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled){	//If we already had a definition running we check if it has a transition to HQ at this chapter.

		switch (chapter){
				case 1:
					currentDefinitionTransitionEventPath = activeMusicDefinition.HQChapter01_TransitionEventPath;
					break;
				case 2:
					currentDefinitionTransitionEventPath = activeMusicDefinition.HQChapter02_TransitionEventPath;
					break;
				case 3:
					currentDefinitionTransitionEventPath = activeMusicDefinition.HQChapter03_TransitionEventPath;
			}
	}

	if(currentDefinitionTransitionEventPath != ""){ //We deliberately don't check if it actually loads an event to help designers debug.
		currentDefinitionTransitionEvent = LoadEventFromPathSync(activeMusicDefinition.Append, currentDefinitionTransitionEventPath);

		PlayLoadedMusicEvent(currentDefinitionTransitionEvent);
		LastCommand = "PlayBaseViewMusic";
		ObtainEventPlayer().SetRTPCValue('chapteRTPC', float(chapter));

		`log("Wwise Mms playing transition to Base View for" @activeMusicDefinition.MusicID);
		return;
	}

	newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_CustomObjective, found); //Transition check out of the way, we find a new definition to play.

	if(found != 0){

		if(newDefinitionToPlay.WwiseEnabled){ //If the new definition is a Wwise definition we find the start event for the current chapter and play it, then return.

			switch (chapter){
				case 1:
					newDefinitionStartEventPath = newDefinitionToPlay.HQChapter01_StartEventPath;
					break;
				case 2:
					newDefinitionStartEventPath = newDefinitionToPlay.HQChapter02_StartEventPath;
					break;
				case 3:
					newDefinitionStartEventPath = newDefinitionToPlay.HQChapter03_StartEventPath;
			}

			if(newDefinitionStartEventPath != ""){
				newDefinitionStartEvent = LoadEventFromPathSync(newDefinitionToPlay.Append, newDefinitionStartEventPath);
			}

			StartMusicDefinitionWithEvent(newDefinitionToPlay,newDefinitionStartEvent);
			ObtainEventPlayer().SetRTPCValue('chapteRTPC', float(chapter));

			LastCommand = "PlayBaseViewMusic";
			`log("Wwise Mms starting from Base View for" @activeMusicDefinition.MusicID);
		
			return;
		}

		PlayMMSMusicDefinition(newDefinitionToPlay);	 //All the Wwise Mms checks done, back to normal MMS.

		LastCommand = "PlayBaseViewMusic";
		`log("Wwise Mms playing standard Base View definition" @activeMusicDefinition.MusicID);
		return;
	}

	`log("Wwise Mms failed to find a music definition for Base View chapter" @chapter $ ".");
	//If there is no HQ music for this chapter then we carry on with whatever was already playing. We don't set LastCommand so as not to break transition checks.

	//CONSIDER ADDING FALLBACK TO OTHER HQ STATES!
}

//----------------------------------------------------------------------------------------------------------------------------PlayGeoscapeMusic
function PlayGeoscapeMusic(){

	local XComGameState_HeadquartersAlien AlienHQ;
	local WwiseMms_StrategyMusicDefinition newDefinitionToPlay;
	local AkEvent transitionEvent;
	local string transitionEventPath;
	local int found;

	if(LastCommand == "PlayGeoscape"){ //Returns if Geoscape is already playing due to unfound intermediate tracks
		return;
	}

	AlienHQ = class'UIUtilities_Strategy'.static.GetAlienHQ(true);

	if (AlienHQ != none && AlienHQ.AIMode == "Lose" && AlienHQ.AtMaxDoom()){ //First we check for Doomclock. If present, we will play and return.
		if(activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled){	//If we already had a Wwise definition running we check if it has a transition from the current state to Doomclock.

			if(activeMusicDefinition.DoomClock_TransitionEventPath != ""){ //If there is a transition to Doomclock then we run it and return.
				transitionEvent = LoadEventFromPathSync(activeMusicDefinition.Append, activeMusicDefinition.DoomClock_TransitionEventPath);
				PlayLoadedMusicEvent(transitionEvent);
				LastCommand = "PlayDoomClockMusic";
				`log("Wwise Mms playing transition to Doomclock for" @activeMusicDefinition.MusicID);
				return;
			}
		}
		
		//We need Doomclock and the current track cannot transition to it, so we find a new definition to play.

		newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_GeoDoomClock, found);

		if (found != 0){ //If we actually have a Doomclock event to play we run it and then return.

			if (newDefinitionToPlay.WwiseEnabled){
				transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append,newDefinitionToPlay.DoomClock_StartEventPath);
				StartMusicDefinitionWithEvent(newDefinitionToPlay,transitionEvent);
				`log("Wwise Mms starting from Doomclock for" @activeMusicDefinition.MusicID);

			}else{

				PlayMMSMusicDefinition(newDefinitionToPlay);
				`log("Wwise Mms playing standard Doomclock definition" @activeMusicDefinition.MusicID);
			}

			LastCommand = "PlayDoomclockMusic";
			return;
		}
	}				//Below is for non-Doomclock geoscape, or if there was no Doomclock music to play.
		

	if(activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled){	//If we already had a Wwise definition running we check if it has a transition from the current state to Geoscape

		if(activeMusicDefinition.Geoscape_TransitionEventPath != ""){ //If there is a transition to Geoscape from the current definition then we run it and return.

			transitionEvent = LoadEventFromPathSync(activeMusicDefinition.Append,activeMusicDefinition.Geoscape_TransitionEventPath);
			PlayLoadedMusicEvent(transitionEvent);
			LastCommand = "PlayGeoscapeMusic";

			`log("Wwise Mms playing transition to Geoscape for" @activeMusicDefinition.MusicID);

			return;
		}
	}//We need Geoscape and the current track cannot transition to it, so we find a new definition to play

	newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_Geoscape, found);

	if (found != 0){ //If we actually have a Geoscape event to play we run it and then return.

		if (newDefinitionToPlay.WwiseEnabled){
			transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append,newDefinitionToPlay.Geoscape_StartEventPath);
			StartMusicDefinitionWithEvent(newDefinitionToPlay,transitionEvent);

			`log("Wwise Mms starting from Geoscape for" @activeMusicDefinition.MusicID);

		}else{

			PlayMMSMusicDefinition(newDefinitionToPlay);
			`log("Wwise Mms playing standard Geoscape definition" @activeMusicDefinition.MusicID);
		}

		LastCommand = "PlayGeoscapeMusic";
		return;
	}
	
	`log("Wwise Mms failed to find a music definition for Geoscape.");
	//If there is no Geoscape music at all then we carry on with whatever was already playing. We don't set LastCommand so as not to break transition checks.
}

//----------------------------------------------------------------------------------------------------------------------------PlaySquadSelectMusic
function PlaySquadSelectMusic(){

	local WwiseMms_StrategyMusicDefinition newDefinitionToPlay;
	local int found;
	local string missionTransitionPath;
	local name missionFamily;
	local XComGameState_MissionSite MissionState;
	local int index;
	local AkEvent missionEvent;
	local AkEvent transitionEvent;

	MissionState = XComGameState_MissionSite(class'XComGameStateHistory'.static.GetGameStateHistory().GetGameStateForObjectID( class'UIUtilities_Strategy'.static.GetXComHQ().MissionRef.ObjectID));
	missionFamily = name(MissionState.GeneratedMission.Mission.MissionFamily);
	if (missionFamily == ''){
		missionFamily = MissionState.GeneratedMission.Mission.MissionName;
	}

	if(activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled && activeMusicDefinition.SquadSelect_TransitionEventPath != ""){	//If we already had a Wwise definition running we check if it has a transition

		index = activeMusicDefinition.SquadSelectMission_EventPaths.Find('theName',missionFamily);
		transitionEvent = LoadEventFromPathSync(activeMusicDefinition.Append,activeMusicDefinition.SquadSelect_TransitionEventPath);

		if(activeMusicDefinition.PlaySquadSelectForAllMissions || index != -1){//If there is a transition to Squad Select from the current definition then we run it and return.
			
			if(index != -1){
				missionTransitionPath = activeMusicDefinition.SquadSelectMission_EventPaths[index].thePath;
				missionEvent = LoadEventFromPathSync(activeMusicDefinition.Append,missionTransitionPath);
				PlayLoadedMusicEvent(transitionEvent);
				PlayLoadedMusicEvent(missionEvent);

			}else {
				PlayLoadedMusicEvent(transitionEvent);
			}
		
			LastCommand = "PlaySquadSelectMusic";
			`log("Wwise Mms playing transition to SquadSelect for" @activeMusicDefinition.MusicID);
			return;
		}
	}

	newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_SquadSelect, found); //We need Squad Select and the current track cannot transition to it, so we find a new definition to play.

	if (found != 0){ //If we actually have a Squad Select event to play we run it and then return.

		if (newDefinitionToPlay.WwiseEnabled){

			index = newDefinitionToPlay.SquadSelectMission_EventPaths.Find('theName',missionFamily);
			transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append,newDefinitionToPlay.SquadSelect_StartEventPath);

			if(index != -1){

				missionTransitionPath = newDefinitionToPlay.SquadSelectMission_EventPaths[index].thePath;
				missionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append,missionTransitionPath);
				StartMusicDefinitionWithEvent(newDefinitionToPlay,transitionEvent);
				PlayLoadedMusicEvent(missionEvent);

			}else{ 
				StartMusicDefinitionWithEvent(newDefinitionToPlay,transitionEvent);
			}
			`log("Wwise Mms starting from SquadSelect for" @activeMusicDefinition.MusicID);

		}else{

			PlayMMSMusicDefinition(newDefinitionToPlay);
			`log("Wwise Mms playing standard SquadSelect definition" @activeMusicDefinition.MusicID);
		}

		LastCommand = "PlaySquadSelectMusic";
		return;
	}
	
	`log("Wwise Mms failed to find a music definition for SquadSelect.");
	//If there is no Squad Select music at all then we carry on with whatever was already playing. We don't set LastCommand so as not to break transition checks.
}


//----------------------------------------------------------------------------------------------------------------------------PlayAfterActionMusic
function PlayAfterActionMusic(){
	
	local bool bCasualties, bVictory;
	local int idx;
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit UnitState;

	local WwiseMms_StrategyMusicDefinition newDefinitionToPlay;
	local int found;
	local string unfoundTypeLabel;
	local bool transitionWorked;
	local AkEvent transitionEvent;

	`log("Wwise Mms Strategy PlayAfterAction called");

	transitionWorked = true;

	if(soundManagerMessenger == none){
		`log("Wwise Mms  Strategy did not find the messenger for after action");
	}


	if(soundManagerMessenger.postTransitionEvent != "" && soundManagerMessenger.postTransitionDefinitionID != ""){	//Ignore all the other rubbish if we have an event to play passed over from tactical
		`log("wwise mms strategy manager found post-transition event for after action");
		
		newDefinitionToPlay = CompleteMusicDefs[CompleteMusicDefs.Find('MusicID',name(soundManagerMessenger.postTransitionDefinitionID))];

		transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append , soundManagerMessenger.postTransitionEvent);

		if(newDefinitionToPlay.isAssigned && transitionEvent != none){

			StartMusicDefinitionWithEvent(newDefinitionToPlay,transitionEvent);

		}else{

			`log("wwise mms strategy manager failed to find the Music  specified by the post-transition event for after action. Reverting to normal.");
			transitionWorked = false;
		}

		if(transitionWorked){
			LastCommand = "PlayAfterActionMusic";
			return;
		}

	}


	soundManagerMessenger.postTransitionEvent = "";
	soundManagerMessenger.postTransitionDefinitionID = "";


	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	bCasualties = false;

	if(BattleData != none){
		bVictory = BattleData.bLocalPlayerWon;

	}else{

		bVictory = XComHQ.bSimCombatVictory;
	}

	if(!bVictory){

		unfoundTypeLabel = "loss";
		newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_AfterActionLoss, found);

		transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append , newDefinitionToPlay.AALoss_StartEventPath);

	}else{

		for(idx = 0; idx < XComHQ.Squad.Length; idx++){
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[idx].ObjectID));
			if(UnitState != none && UnitState.IsDead()){
				bCasualties = true;
				break;
			}
		}

		if(bCasualties){
			//SetSwitch('StrategyScreen', 'PostMissionFlow_Pass');
			unfoundTypeLabel = "win with casualties";
			newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_AfterActionCasualties, found);
			transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append , newDefinitionToPlay.AACasualties_StartEventPath);

		}else{

			//SetSwitch('StrategyScreen', 'PostMissionFlow_FlawlessVictory');
			unfoundTypeLabel = "Flawless";
			newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_AfterActionFlawless, found);
			transitionEvent = LoadEventFromPathSync(newDefinitionToPlay.Append , newDefinitionToPlay.AAFlawless_StartEventPath);
		}
	}

	if (found != 0){ //If we actually have an after action event to play we run it and then return.
		if (newDefinitionToPlay.WwiseEnabled){
			StartMusicDefinitionWithEvent(newDefinitionToPlay,transitionEvent);
			`log("Wwise Mms starting from After Action for" @activeMusicDefinition.MusicID);

		}else{

			PlayMMSMusicDefinition(newDefinitionToPlay);
			`log("Wwise Mms playing standard After Action definition" @activeMusicDefinition.MusicID);
		}

		LastCommand = "PlayAfterActionMusic";
		return;
	}

	`log("Wwise Mms failed to find a music definition for After Action state" @unfoundTypeLabel);
	//If there is no after action music then we just let it do its thing
}

//----------------------------------------------------------------------------------------------------------------------------PlayCreditsMusic
function PlayCreditsMusic(){ //Remember, there is no playthrough from a previous state so you had better hope that you find something!

	local WwiseMms_StrategyMusicDefinition newDefinitionToPlay;
	local int found;
	local AkEvent theEvent;

	newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_Credits, found);

	if(found != 0){

		if(newDefinitionToPlay.WwiseEnabled){
			theEvent = LoadEventFromPathSync(newDefinitionToPlay.Append , newDefinitionToPlay.WinCredits_StartEventPath);

			StartMusicDefinitionWithEvent(newDefinitionToPlay,theEvent);
			LastCommand = "PlayCreditsMusic";

			`log("Wwise Mms starting from Win Credits for" @activeMusicDefinition.MusicID);

			return;
		}

		PlayMMSMusicDefinition(newDefinitionToPlay);
		LastCommand = "PlayCreditsMusic";

		`log("Wwise Mms playing standard Win Credits definition" @activeMusicDefinition.MusicID);
		return;
	}

	`log("Wwise Mms failed to find a music definition for Win Credits.");
}

//----------------------------------------------------------------------------------------------------------------------------PlayLossMusic
function PlayLossMusic(){

	local WwiseMms_StrategyMusicDefinition newDefinitionToPlay;
	local int found;
	local AkEvent theEvent;

	newDefinitionToPlay = WwiseMms_GetMusicDefForEvent(weSSG_Loss, found);

	if(found != 0){

		if(newDefinitionToPlay.WwiseEnabled){
			theEvent = LoadEventFromPathSync(newDefinitionToPlay.Append , newDefinitionToPlay.LoseCredits_StartEventPath);

			StartMusicDefinitionWithEvent(newDefinitionToPlay,theEvent);
			LastCommand = "PlayCreditsMusic";

			`log("Wwise Mms starting from Loss Credits for" @activeMusicDefinition.MusicID);

			return;
		}

		PlayMMSMusicDefinition(newDefinitionToPlay);
		LastCommand = "PlayLossMusic";

		`log("Wwise Mms playing standard Lose Credits definition" @activeMusicDefinition.MusicID);
		return;
	}

	`log("Wwise Mms failed to find a music definition for Lose Credits.");
	//Sorry player, no credits music. Consider allowing fallback even if disabled when nothing is found here.

}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_RewriteConvenienceChapters
function WwiseMms_RewriteConvenienceChapters(){

	local WwiseMms_StrategyMusicDefinition Def;
	local int i;

	CompleteMusicDefs = CompileFullDefinitionList();

	//	This will do all the standard definitions
	foreach CompleteMusicDefs(Def, i){
		if(Def.WwiseEnabled){continue;}

		if (Def.Group == weSSG_Chapter01){
			CompleteMusicDefs[i].Group = weSSG_CustomObjective;
			CompleteMusicDefs[i].Objective.Objective = '';
			ChapterOneIDs.AddItem(Def.MusicID);
		}
		if (Def.Group == weSSG_Chapter02){
			CompleteMusicDefs[i].Group = weSSG_CustomObjective;
			CompleteMusicDefs[i].Objective.Objective = 'T3_M2_BuildShadowChamber';
			ChapterTwoIDs.AddItem(Def.MusicID);
		}
		if (Def.Group == weSSG_Chapter03){
			CompleteMusicDefs[i].Group = weSSG_CustomObjective;
			CompleteMusicDefs[i].Objective.Objective = 'T1_M6_StopAvatar';
			ChapterThreeIDs.AddItem(Def.MusicID);
		}
	}


	//	This will do all the Wwise Mms definitions
	foreach CompleteMusicDefs(Def, i){
		if(!Def.WwiseEnabled){continue;}

		if (CheckMusicDefinitionForSoundGroupEquivalence(Def,weSSG_Chapter01)){
			CompleteMusicDefs[i].Group = weSSG_CustomObjective;
			CompleteMusicDefs[i].Objective.Objective = '';
			ChapterOneIDs.AddItem(Def.MusicID);
		}

		if (CheckMusicDefinitionForSoundGroupEquivalence(Def,weSSG_Chapter02)){
			CompleteMusicDefs[i].Group = weSSG_CustomObjective;
			CompleteMusicDefs[i].Objective.Objective = 'T3_M2_BuildShadowChamber';
			ChapterTwoIDs.AddItem(Def.MusicID);
		}

		if (CheckMusicDefinitionForSoundGroupEquivalence(Def,weSSG_Chapter03)){
			CompleteMusicDefs[i].Group = weSSG_CustomObjective;
			CompleteMusicDefs[i].Objective.Objective = 'T1_M6_StopAvatar';
			ChapterThreeIDs.AddItem(Def.MusicID);
		}
	}

	`log("Wwise Mms - Rewrite Convenience Chapters");
}

//----------------------------------------------------------------------------------------------------------------------------PlayMMSMusicDefinition
function PlayMMSMusicDefinition(WwiseMms_StrategyMusicDefinition Def){

	local Wwise_Mms_Strategy_TrackPlayer Player;
	local Wwise_Mms_Strategy_TrackPlayer NewPlayer;

	StopWwiseMmsPlayer();

	WwiseMms_GetFreePlayerForDef(Def, NewPlayer);


	foreach wPlayers(Player){
	if (NewPlayer != Player && Player.IsPlaying())
		{
			`log("Wwise Mms stopped" @ Player.TrackID);
			Player.StopMusic();
		}
	}

	if (!NewPlayer.IsPlaying()){
		`log("Wwise Mms starting" @ NewPlayer.TrackID);
		NewPlayer.Play();
	}

	activeMusicDefinition = Def;
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_GetFreePlayerForDef
function bool WwiseMms_GetFreePlayerForDef(WwiseMms_StrategyMusicDefinition Def, out Wwise_Mms_Strategy_TrackPlayer oPlayer){

	local Wwise_Mms_Strategy_TrackPlayer APlayer;

	foreach wPlayers(APlayer){
		if ((APlayer.TrackID == Def.MusicID || APlayer.Def.CuePath == Def.CuePath) && APlayer.IsPlaying()){
			oPlayer = APlayer;

			`log("Wwise_Mms -" @ "A Player is playing" @ Def.MusicID @ "At the moment");

			return false;
		}
	}
	
	foreach wPlayers(APlayer){
		if (!APlayer.IsPlaying()){
			APlayer.WwiseMms_Normal_InitStrategyPlayer(Def);
			oPlayer = APlayer;

			`log("Wwise_Mms -" @ "Idle player");

			return false;
		}
	}

	APlayer = Spawn(class'Wwise_Mms_Strategy_TrackPlayer', self);
	APlayer.WwiseMms_Normal_InitStrategyPlayer(Def);
	wPlayers.AddItem(APlayer);
	oPlayer = APlayer;

	`log("Wwise_Mms -" @ "created new player");

	return true;
}

//----------------------------------------------------------------------------------------------------------------------------CompileFullDefinitionList
function array<WwiseMms_StrategyMusicDefinition> CompileFullDefinitionList(){

	local MusicDefinition oldDef;
	local array<WwiseMms_StrategyMusicDefinition> newList;
	local name iName;
	local WwiseMms_StrategyMusicDefinition iDef; 
	local int i;
	
	newList = WiserStrategyMusicDefs;


	if(MusicDefs.Length != 0 || MusicDefs[0].MusicID != ''){
		foreach MusicDefs(oldDef){
			newList.AddItem(ConvertStandardDefinitionToWwiseMmsDefinition(oldDef));
		}
	}

	for (i = 0; i < newList.Length; i++){
		newList[i].isAssigned = true; 
	}

	`log("--------------------Wwise Mms Printing Strategy Fallback List!--------------------");
	foreach FallbackIDs(iName){																			`log(iName);}
	`log("--------------------Finished Printing Strategy Fallback List!---------------------");

	`log("--------------------Wwise Mms Printing full Strategy List!--------------------");
	foreach newList(iDef){																				`log(iDef.MusicID);}
	`log("--------------------Finished Printing Full Strategy List!---------------------");


	return newList;
}

//----------------------------------------------------------------------------------------------------------------------------ConvertStandardDefinitionToWwiseMmsDefinition
function WwiseMms_StrategyMusicDefinition ConvertStandardDefinitionToWwiseMmsDefinition(MusicDefinition oldDef){

	local WwiseMms_StrategyMusicDefinition newDef;

	newDef.MusicID = Name("Converted From MMS " $ String(oldDef.MusicID));
	newDef.CuePath = oldDef.CuePath;
	newDef.IntroCue = oldDef.IntroCue;
	newDef.IntroLength = oldDef.IntroLength;
	newDef.dontFadeIn = oldDef.dontFadeIn;
	newDef.dontFadeOut = oldDef.dontFadeOut;
	newDef.Group = ConvertMMSSoundGroupToWwiseMmsSoundGroup(oldDef.Group);
	newDef.Objective = oldDef.Objective;
	newDef.MissionName = oldDef.MissionName;
	newDef.WwiseEnabled = false;
	
	if (FallbackSongs.Find(oldDef.MusicID) != INDEX_NONE){
		FallbackIDs.AddItem(newDef.MusicID);
	}

	return(NewDef);
}

//----------------------------------------------------------------------------------------------------------------------------ConvertMMSSoundGroupToWwiseMmsSoundGroup
function WwiseMms_EStrategySoundGroup ConvertMMSSoundGroupToWwiseMmsSoundGroup(EStrategySoundGroup oldGroup){	

//This whole thing is not longer actually nessecary since I am no longer using extra groups. I should perhaps take it out at some point.
	if(oldGroup == eSSG_Chapter01){return weSSG_Chapter01;}
	if(oldGroup == eSSG_Chapter02){return weSSG_Chapter02;}
	if(oldGroup == eSSG_Chapter03){return weSSG_Chapter03;}
	if(oldGroup == eSSG_Geoscape){return weSSG_Geoscape;}
	if(oldGroup == eSSG_GeoDoomClock){return weSSG_GeoDoomClock;}
	if(oldGroup == eSSG_SquadSelect){return weSSG_SquadSelect;}
	if(oldGroup == eSSG_SquadSelectMission){return weSSG_SquadSelectMission;}
	if(oldGroup == eSSG_Credits){return weSSG_Credits;}
	if(oldGroup == eSSG_Loss){return weSSG_Loss;}
	if(oldGroup == eSSG_AfterActionFlawless){return weSSG_AfterActionFlawless;}
	if(oldGroup == eSSG_AfterActionCasualties){return weSSG_AfterActionCasualties;}

	return weSSG_AfterActionLoss;
}

//----------------------------------------------------------------------------------------------------------------------------CheckMusicDefinitionForSoundGroupEquivalence
function bool CheckMusicDefinitionForSoundGroupEquivalence(WwiseMms_StrategyMusicDefinition defToTest, WwiseMms_EstrategySoundGroup groupToTest){

	local bool test;

	test = (defToTest.Group == groupToTest);

	if(test){									return(test); //This should sort out all of the standard MMS entries which match because they each have a fixed group.
	}						

	if(!defTotest.WwiseEnabled){				return false; //Sorts out any non-matching standard entries which got through. After this all entries should be Wwise.
	}

	switch (groupToTest){
		case weSSG_CustomObjective:
			test = (defToTest.HQChapter01_StartEventPath != "");

			if(!test){test = (defToTest.HQChapter02_StartEventPath != "");
			}
			if(!test){test = (defToTest.HQChapter03_StartEventPath != "");
			}

			return(test);
			break;

		case weSSG_Chapter01:
			return(defToTest.HQChapter01_StartEventPath != "");
			break;

		case weSSG_Chapter02:
			return(defToTest.HQChapter02_StartEventPath != "");
			break;
			
		case weSSG_Chapter03:
			return(defToTest.HQChapter03_StartEventPath != "");
			break;

		case weSSG_Geoscape:
			return(defToTest.Geoscape_StartEventPath != "");
			break;

		case weSSG_GeoDoomClock:
			return(defToTest.DoomClock_StartEventPath != "");
			break;

		case weSSG_SquadSelectMission:
		case weSSG_SquadSelect:
			return(defToTest.SquadSelect_StartEventPath != "");
			break;

		case weSSG_SquadSelectMission:
			return(defToTest.SquadSelect_StartEventPath != "");
			break;

		case weSSG_Credits:
			return(defToTest.WinCredits_StartEventPath != "");
			break;

		case weSSG_Loss:
			return(defToTest.LoseCredits_StartEventPath != "");
			break;

		case weSSG_AfterActionFlawless:
			return(defToTest.aaFlawless_StartEventPath != "");
			break;

		case weSSG_AfterActionCasualties:
			return(defToTest.aaCasualties_StartEventPath != "");
			break;

		case weSSG_AfterActionLoss:
			return(defToTest.aaLoss_StartEventPath != "");
			break;

		default:
			`log("Wwise Mms Group equivalence check failure, something is wrong!");
			return false;
	}
}

//----------------------------------------------------------------------------------------------------------------------------CheckMusicDefinitionForCurrentHQTransition
function string CheckMusicDefinitionForCurrentHQTransition(WwiseMms_StrategyMusicDefinition defToTest){

	if(defTotest.HQChapter01_TransitionEventPath == "" && defTotest.HQChapter02_TransitionEventPath == "" && defTotest.HQChapter03_TransitionEventPath == ""){
		return "";
	}
	
	if(defTotest.HQChapter03_TransitionEventPath != "" && currentChapterNumber() == 3){
		return defTotest.HQChapter03_TransitionEventPath;
	}

	if(defTotest.HQChapter02_TransitionEventPath != "" && currentChapterNumber() == 2){
		return defTotest.HQChapter02_TransitionEventPath;
	}

	return defTotest.HQChapter01_TransitionEventPath;
}

//----------------------------------------------------------------------------------------------------------------------------ObtainEventPlayer
function Wwise_Mms_AkEventPlayer ObtainEventPlayer(){
	
	if (eventPlayer != none){																			return eventPlayer;
	}

	eventPlayer = Spawn(class'Wwise_Mms_AkEventPlayer', self);							`log("Wwise Mms finds no event player! Creating...");
																										return eventPlayer;
}

//----------------------------------------------------------------------------------------------------------------------------StopMMSPlayers
function StopMMSPlayers(){
	local Wwise_Mms_Strategy_TrackPlayer Player;

	foreach wPlayers(Player){
		Player.StopMusic();
		Player.Reset();
	}
}

//----------------------------------------------------------------------------------------------------------------------------StopMMSPlayers
function StopWwiseMmsPlayer(){

	local Wwise_Mms_AkEventPlayer myPlayer;

	myPlayer = ObtainEventPlayer();
	myPlayer.StopMusic();
	myPlayer.EndEvent = none;
}


//----------------------------------------------------------------------------------------------------------------------------PlayLoadedMusicEventFromPath
function PlayLoadedMusicEvent(AkEvent eventToPlay){

	local Wwise_Mms_AkEventPlayer myPlayer;

	nextEvent = eventToPlay;
	myPlayer = ObtainEventPlayer();

	`log("Wwise Mms strategy manager playing" @eventToPlay );

	myPlayer.PlayEvent(nextEvent);

}

//----------------------------------------------------------------------------------------------------------------------------StartMusicDefinitionWithEvent
function StartMusicDefinitionWithEvent(WwiseMms_StrategyMusicDefinition ownerDefinition, AkEvent startEvent){

	StopMMSPlayers();
	StopWwiseMmsPlayer();

	if(ownerDefinition.End_EventPath != ""){
		ObtainEventPlayer().endEvent = LoadEventFromPathSync(ownerDefinition.Append,ownerDefinition.End_EventPath);
	}else{
		ObtainEventPlayer().endEvent = none;
	}

	PlayLoadedMusicEvent(startEvent);
	activeMusicDefinition = ownerDefinition;
}

//----------------------------------------------------------------------------------------------------------------------------CurrentChapterNumber
function int CurrentChapterNumber(){

	//local XComGameState_Objective iObjective;
	//foreach class'XComGameStateHistory'.static.GetGameStateHistory().IterateByClassType(class'XComGameState_Objective', iObjective){
		//`log("Wwise Mms strategy objective:" @iObjective.GetMyTemplateName());
	//}
	if(class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T1_M6_KillAvatar')){
		return 3;
	}

	if(class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T3_M2_BuildShadowChamber')){
		return 2;
	}

	return 1;
}

//----------------------------------------------------------------------------------------------------------------------------PlayHQMusicEvent
function PlayHQMusicEvent(){

	`log("Wwise Mms -" @ "PlayHQMusic Called - last command is : " $ LastCommand $ ", and bSkipPlayHQMusicAfterTactical is" @ bSkipPlayHQMusicAfterTactical);

	if(!XComStrategySoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).bSkipPlayHQMusicAfterTactical){
		//StopSounds();

	}else{

		 //This flag is set in the state where X-Com returns from a mission. In this situation the HQ music is already playing
		XComStrategySoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).bSkipPlayHQMusicAfterTactical = false; 		
		// re: well, perfect. so let's stop it then
		PlayAkEvent(StopHQMusic);
	}
}

//----------------------------------------------------------------------------------------------------------------------------StopHQMusicEvent
function StopHQMusicEvent(){

	`log("Wwise Mms -" @ "StopHQMusic called - last command: " $ LastCommand $ ", and bSkipPlayHQMusicAfterTactical is" @ bSkipPlayHQMusicAfterTactical);

	if(!XComStrategySoundManager(XComGameReplicationInfo(class'Engine'.static.GetCurrentWorldInfo().GRI).GetSoundManager()).bSkipPlayHQMusicAfterTactical){
		PlayAkEvent(StopHQMusic); 
	}
}


//----------------------------------------------------------------------------------------------------------------------------WwiseMms_GetMusicDefForEvent
function WwiseMms_StrategyMusicDefinition WwiseMms_GetMusicDefForEvent(WwiseMms_EStrategySoundGroup evt, optional out int bFound){

	local int idx;
	local array<int> idxs;
	local array<int> nonfallbackidxs;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_MissionSite MissionState;
	local XComGameStateHistory History;
	local WwiseMms_StrategyMusicDefinition iDef;
	local WwiseMms_StrategyMusicDefinition defToReturn;
	local int chapter;
	local name missionFamily;
	

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));
	chapter = CurrentChapterNumber();
	missionFamily = name(MissionState.GeneratedMission.Mission.MissionFamily);
	if (missionFamily == ''){
		missionFamily = MissionState.GeneratedMission.Mission.MissionName;
	}

	// The convenience chapters are applied which sorts the HQ options.
	foreach CompleteMusicDefs(iDef, idx){
		if (CheckMusicDefinitionForSoundGroupEquivalence(iDef,evt)){ //Everything that we are now checking can start at this event. Sub-event checks begin.
			switch (evt){ //Special behaviour for squad select and Base View

				case weSSG_CustomObjective: //Gets music for the correct chapter
					switch (chapter){
						case 1:
							if(ChapterOneIDs.find(iDef.MusicID) != INDEX_NONE){
								idxs.AddItem(idx);
							}
							break;
						case 2:
							if(ChapterTwoIDs.find(iDef.MusicID) != INDEX_NONE){
								idxs.AddItem(idx);
							}
							break;
						case 3:
							if(ChapterThreeIDs.find(iDef.MusicID) != INDEX_NONE){
								idxs.AddItem(idx);
							}
							break;
					}
					break;

				case weSSG_SquadSelectMission: //We can sort the mission dependance thing out here.
				case weSSG_SquadSelect:
					if(iDef.WwiseEnabled){ //If this definition supports our current mission OR if it supports all missions and MixInIndifferent is enabled then we want it.
						if(iDef.SquadSelectMission_EventPaths.Find('theName',missionFamily) != INDEX_NONE 
							|| (class'MMS_UISL_MCM'.default.bMixInIndifferent && iDef.PlaySquadSelectForallMissions)){
							idxs.AddItem(idx);
						}

					}else{
								
						if(iDef.MissionName == MissionState.GetMissionSource().DataName
							||(iDef.Group == weSSG_SquadSelect && class'MMS_UISL_MCM'.default.bMixInIndifferent)){   
							idxs.AddItem(idx);  //if this definition is for this mission specifically OR it is generic and MixInIndifferent is enabled then we want it.
						}
					}
					break;

				default:
					idxs.AddItem(idx);
					break;
			}
		}
	}

	//At this point we have a full list of indicies for Music Definitions which are appropriate to this event.

	if(idxs.Length > 0){
		bFound = 1;
	}else{
		bFound = 0;
	}


	if(bFound == 0){
		`log("Wwise Mms could not find a music definition compatible with" @ evt);
		return defToReturn;
	}

	// compile list without fallback
	foreach idxs(idx){
		if (FallbackIDs.find(CompleteMusicDefs[idx].MusicID) == INDEX_NONE){
			nonfallbackidxs.AddItem(idx);

		}
	}


	// there are non-fallback songs AND the user doesn't want fallback
	if (nonfallbackidxs.Length > 0 && !class'MMS_UISL_MCM'.default.bAllowFallback){
		defToReturn = CompleteMusicDefs[nonfallbackidxs[Rand(nonfallbackidxs.Length)]];
		
	}else{
		`Log("No appropriate custom definitions found or fallback enabled, reverting to fallback list. Nonfallback list size is" @nonfallbackidxs.Length);
		defToReturn = CompleteMusicDefs[idxs[Rand(idxs.Length)]];
	}

	`log("wwise mms fallback state is" @class'MMS_UISL_MCM'.default.bAllowFallback);


																									`log("Wwise Mms found" @ defToReturn.MusicID @ "for" @ evt $".");
	return defToReturn;
}

//----------------------------------------------------------------------------------------------------------------------------Event - OnCleanupWorld
simulated event OnCleanupWorld(){

	`log("Wwise Mms strategy - Mopped up");

	ObtainEventPlayer().StopMusic();
	Cleanup();
	super.OnCleanupWorld();
}

//----------------------------------------------------------------------------------------------------------------------------Event - Destroyed
event Destroyed(){

	`log("Wwise Mms - Destroyed");

	super.Destroyed();
	Cleanup();
}

//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
function bool GetFreePlayerForDef(MusicDefinition Def, out MMS_Strategy_TrackPlayer oPlayer){						`log("Wwise MMS GetFreePlayerForDef intercepted.");	return false;}
function MusicDefinition GetMusicDefForEvent(EStrategySoundGroup evt, optional out int bFound){						`log("Wwise MMS GetMusicDefForEvent intercepted.");	return LastLoadoutDef;}
function PlayMusicEvent(MusicDefinition Def){																		`log("Wwise MMS PlayMusicEvent intercepted.");}
//function PlayMusic(SoundCue NewMusicCue, optional float FadeInTime=0.0f){											`log("Wwise Mms Firaxis PlayMusic intercepted.");}
//function StopMusic(optional float FadeOutTime=1.0f){																`log("Wwise Mms Firaxis StopMusic intercepted.");}
protected function StartAmbience(out AmbientChannel Ambience, optional float FadeInTime=0.5f){						`log("Wwise Mms Firaxis Start Ambience intercepted.");}
protected function StopAmbience(out AmbientChannel Ambience, optional float FadeOutTime=1.0f){						`log("Wwise Mms Firaxis Stop Ambience intercepted.");}
protected function SetAmbientCue(out AmbientChannel Ambience, SoundCue NewCue){										`log("Wwise Mms Firaxis Set Ambience intercepted.");}
function RewriteConvenienceChapters(){																				`log("Wwise MMS RewriteConvenienceChapters intercepted.");}

//These functions are how the game tells MMS that it wants something done, so we can't intercept them.
//function PlayBaseViewMusic(){																						`log("MMS PlayBaseViewMusic intercepted.");}
//function PlayGeoscapeMusic(){																						`log("MMS PlayGeoscapeMusic intercepted.");}
//function PlaySquadSelectMusic(){																					`log("MMS PlaySquadSelectMusic intercepted.");}
//function PlayCreditsMusic(){																						`log("MMS PlayCreditsMusic intercepted.");}
//function PlayLossMusic(){																							`log("MMS PlayLossMusic intercepted.");}
//function PlayAfterActionMusic(){																					`log("MMS PlayAfterActionMusic intercepted.");}

defaultproperties
{
	updatePeriod = 0.3f
	LastCommand = ""
	bKillDuringLevelTransition = false
}