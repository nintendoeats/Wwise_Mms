//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_XComTacticalSoundManager.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Partially bypasses the wwise implementation of combat and post-mission music
//
//	FILE:		Wwise_Mms_XComTacticalSoundManager.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Allows interactive music using AkEvents to be mixed in with standard MMS packs For Tactical
//---------------------------------------------------------------------------------------

//Alternate private variables are indicated by a "w" prefix.
//Alternate functions and classes are indicated by a "WwiseMms_" Prefix
//The list of Wwise Mms combat and explore music definitions are called
//	WiserCombatDefs and WiserExploreDefs to make the difference more obvious in configs

class Wwise_Mms_XComTacticalSoundManager extends MMS_XComTacticalSoundManager 
dependson(Wwise_Mms_XComStrategySoundManager) config(TacticalSound) config(WiseSound);

struct WwiseMms_TacticalMusicDefinition
{
	var name								MusicID;
	var bool								type; // false - explore, true - tactical
	var name								MissionMusicSet;
	var	EnvironmentRequirement				EnvReq;
	var	ExploreMusic						Exp;
	var	CombatMusicSet						Com;

	var bool								WwiseEnabled;
	var bool								isAssigned;

	var int									Lifespan;
	var string								Append;
	var string								End_EventPath;

	var bool								PlayForAllTimesOfDay; //Selection based on TOD not currently implemented
	var bool								PlayForAllEnvironments;
	var bool								PlayForAllBiomes;
	var bool								PlayForAllMissions;

	var array<NameAndPath>					Biome_EventPaths;
	var array<NameAndPath>					Environment_EventPaths;
	var array<NameAndPath>					Mission_EventPaths;
	var array<NameAndPath>					TimeOfDay_EventPaths;

	var array<string>						LivingEnemyCount_EventPaths;
	var array<string>						VisibleEnemyCount_EventPaths;
	var array<string>						AlertedEnemyCount_EventPaths;

	var array<NameAndPath>					LivingEnemyType_TrueEventPaths;
	var array<NameAndPath>					AlertedEnemyType_TrueEventPaths;
	var array<NameAndPath>					VisibleEnemyType_TrueEventPaths;

	var array<NameAndPath>					LivingEnemyType_FalseEventPaths;
	var array<NameAndPath>					AlertedEnemyType_FalseEventPaths;
	var array<NameAndPath>					VisibleEnemyType_FalseEventPaths;

	var array<string>						DeadSoldierCount_EventPaths;
	var array<string>						OverwatchingSoldierCount_EventPaths;

	var array<string>						TurnsTakenCount_EventPaths;
	var array<string>						TurnsRemainingCount_EventPaths;
	var array<string>						TurnsSinceEnemySeenCount_EventPaths;

	var array<string>						HitStreakCount_EventPaths;
	var array<string>						MissStreakCount_EventPaths;

	var string								ScamperStarted_EventPath;
	var string								ScamperFinished_EventPath;
	
	var string								ExploreConcealed_StartEventPath;
	var string								ExploreExposed_StartEventPath;
	var string								XCombat_StartEventPath;
	var string								ACombat_StartEventPath;

	var string								AExplore_TransitionEventPath;
	var string								XExplore_TransitionEventPath;
	var string								AExplore_Concealed_TransitionEventPath;
	var string								XExplore_Concealed_TransitionEventPath;
	var string								ACombat_TransitionEventPath;
	var string								XCombat_TransitionEventPath;
	

	structdefaultproperties
	{
		WwiseEnabled = true;
		isAssigned = false;

		Lifespan = 480;
		Append = "";

		PlayForAllTimesOfDay = true;
		PlayForAllEnvironments = true;
		PlayForAllBiomes = true;
		PlayForAllMissions = true;
	}
};

struct WwiseMms_AfterActionMusicDefinition{
	var name MusicID;
	var string Append;

	var bool PlayForAllMissions;
	var array<NameAndPath> Mission_EventList;

	var string StrategyDefinition_MusicID;

	var string StartFlawless_EventPath;
	var string StartCasualties_EventPath;
	var string StartLoss_EventPath;

	var string StrategyStartFlawless_EventPath;
	var string StrategyStartCasualties_EventPath;
	var string StrategyStartLoss_EventPath;

	var string LaunchButton_EventPath;

	structdefaultproperties
	{
		PlayForallMissions = true;
	}
};

/////////////////////////////////////////////////////////////////////////////////

var bool fullMusicDefinitionsListCompiled;
var bool inCombatMode;
var private bool wbAmbienceStarted;

var privatewrite int wNumCombatEvents;
var private int wNumAlertedEnemies;
var float updatePeriod;
var float currentDefinitionTimer;

var string LastCommand;

var array<name> FallbackIDs; //Replaces FallbackDefs for the sake of naming consistency for each manager. Builds partially from +FallbackDefs in the config.
var config array<WwiseMms_TacticalMusicDefinition> WiserTacticalMusicDefs;
var array<WwiseMms_TacticalMusicDefinition> CompleteMusicDefs;

var config array<WwiseMms_AfterActionMusicDefinition> AfterActionDefs;

var Wwise_Mms_AkEventPlayer eventPlayer;

var Wwise_Mms_Tactical_CombatPlayer wCombatPlayer01;
var Wwise_Mms_Tactical_CombatPlayer wCombatPlayer02;
var Wwise_Mms_Tactical_ExplorePlayer wExplorePlayer01;
var Wwise_Mms_Tactical_ExplorePlayer wExplorePlayer02;

var WwiseMms_TacticalMusicDefinition emptyMusicDefinition;
var WwiseMms_TacticalMusicDefinition activeMusicDefinition;
var WwiseMms_TacticalMusicDefinition nextCombatDefinition;
var WwiseMms_TacticalMusicDefinition nextExploreDefinition;

var Wwise_Mms_TransitionData soundManagerMessenger;

var Wwise_Mms_TacticalBuddy myBuddy;

var bool missionOver;

var name biome;
var name missionFamily;
var name environment;
var ETimeOfDay timeOfDay;

var bool startedFromTransition;
var config array<string> VeryWiseSoundBankNames;
var array<AkBank> VeryWiseSoundBanks;

//-------------------------------------------------------------------------------------------------------------------------------------------------------------Init
function Init(){

	super.Init();
	KillDropship();
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------Tick
function Tick( float deltaTime){

	currentDefinitionTimer += deltaTime;
	
	if(!activeMusicDefinition.isAssigned){//Haaaaaaaaaaaaack
		KillDropship();
	}
}

//----------------------------------------------------------------------------------------------------------------------------Event - PreBeginPlay
event PreBeginPlay(){

	local int idx;
	local XComContentManager ContentMgr;

	super.PreBeginPlay();

	ContentMgr = XComContentManager(class'Engine'.static.GetEngine().GetContentManager());

		// Load Banks
	for(idx = 0; idx < VeryWiseSoundBankNames.Length; idx++){
		ContentMgr.RequestObjectAsync(VeryWiseSoundBankNames[idx], self, OnVeryWiseBankLoaded);
	}
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


//-------------------------------------------------------------------------------------------------------------------------------------------------------------OnPlayerTurnBegin
function EventListenerReturn OnPlayerTurnBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	local X2EventManager EventManager;
	local Object ThisObject;
	local XComGameState_Player playerFromEvent;

	playerFromEvent = XComGameState_Player(EventData);	

	if(playerFromEvent.TeamFlag == eTeam_XCom){

		DoMusicStart();

		ThisObject = self;
		EventManager = class'X2EventManager'.static.GetEventManager();
		EventManager.UnRegisterFromEvent(ThisObject, 'PlayerTurnBegun');

	}
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------OnTacticalGameEnd
function EventListenerReturn OnTacticalGameEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	missionOver = true;
	`log("Wwise Mms detects mission end");

	return ELR_NoInterrupt;
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------BeginTacticalBuddy
function BeginTacticalBuddy(){

	if(myBuddy == none){
		myBuddy = Spawn(Class'Wwise_Mms_TacticalBuddy',self);
		myBuddy.Kickstart();
	}

	myBuddy.myBoss = self;

	KillDropship();
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------StartAllAmbience
function StartAllAmbience(bool bStartMissionSoundtrack = true){

	local XComGameState_BattleData P_BattleData;
	local string P_sBiome;
	local string P_sEnvironmentLightingMapName;
	local PlotDefinition P_PlotDef;
	local name P_nBiomeSwitch;
	local name P_nClimateSwitch;
	local name P_nLightingSwitch;

	local X2EventManager EventManager;
	local Object ThisObject;

	if(!wbAmbienceStarted){

		`log("Wwise Mms -" @ "Starting Ambience");

		// Get the relevant environment ambiance settings.
		P_BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
		P_sBiome = P_BattleData.MapData.Biome;
		P_sEnvironmentLightingMapName = P_BattleData.MapData.EnvironmentLightingMapName;
		P_PlotDef = `PARCELMGR.GetPlotDefinition(P_BattleData.MapData.PlotMapName);

		// Convert the ambiance settings to their corresponding AkAudio Switch names.
		P_nBiomeSwitch = Name(P_PlotDef.AudioPlotTypeOverride != "" ? P_PlotDef.AudioPlotTypeOverride : P_PlotDef.strType);
		P_nClimateSwitch = Name(P_sBiome);
		P_nLightingSwitch = GetSwitchNameFromEnvLightingString(P_sEnvironmentLightingMapName);

		// Set the ambiance switches, and play the ambiance event.
		StopAllAmbience();
		//StopSounds();

		if(`TACTICALRULES.bRain){		SetState('Weather', 'Rain');
		}else{							SetState('Weather', 'NoRain');
		}

		SetState('Climate', P_nClimateSwitch);
		SetState('Lighting', P_nLightingSwitch);
		SetState('Biome', P_nBiomeSwitch);
		PlayAkEvent(MapAmbienceEvent);

		startedFromTransition = false;
		ThisObject = self;


		if(X2TacticalGameRuleset(`GAMERULES).bLoadingSavedGame){
			soundManagerMessenger.ResetValues();
			DoMusicStart();
			
		}else{
			
			EventManager = class'X2EventManager'.static.GetEventManager();
			EventManager.RegisterForEvent(ThisObject, 'PlayerTurnBegun', OnPlayerTurnBegin, ELD_OnVisualizationBlockCompleted);	
			`log("wwise mms will start on next player turn");

			DoTransitionFromSkyranger();
		}

		EventManager = class'X2EventManager'.static.GetEventManager();
		EventManager.RegisterForEvent(ThisObject, 'TacticalGameEnd', OnTacticalGameEnd, ELD_Immediate);	

		LastCommand = "StartAllAmbience";
		wbAmbienceStarted = true;
	}

	KillDropship();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------KillDropship
function KillDropship(){ //This only needs to work for LW2, vanilla is dealt with by Robojumper's Kismet.

	SetSwitch( 'TacticalCombatState', 'None' );
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------DoTransitionFromSkyranger
function DoTransitionFromSkyranger(){
	
	local int i;

	if(!bAllMusicTransferred || !fullMusicDefinitionsListCompiled){	
		CompleteMusicDefs = CompileFullMusicDefinitionsList();
	}

	startedFromTransition = false;

	if(soundManagerMessenger.postTransitionEvent != "" && soundManagerMessenger.postTransitionDefinitionID != ""){
		`log("Wwise Mms searching for transition from strategy to tactical at DoTransitionFromSkyranger.");
		i = CompleteMusicDefs.Find(Name("MusicID"),Name(soundManagerMessenger.PostTransitionDefinitionID));

		`log("Wwise Mms transition found and played from strategy to tactical at DoTransitionFromSkyranger.");

		if (i != -1){
			startedFromTransition = true;
			nextExploreDefinition = CompleteMusicDefs[i];
			StartMusicDefinitionWithEvent(nextExploreDefinition,soundManagerMessenger.postTransitionEvent);
			activeMusicDefinition = nextExploreDefinition;

			`log("Wwise Mms transition found and played from strategy to tactical at DoTransitionFromSkyranger. Event Path is" @soundManagerMessenger.postTransitionEvent);
			return; //Great! We transitioned!

		}

	}

	KillDropship();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------DoMusicStart
function DoMusicStart(){

	local int i;

	wCombatPlayer01 = Spawn(class'Wwise_Mms_Tactical_CombatPlayer', self);
	wCombatPlayer02 = Spawn(class'Wwise_Mms_Tactical_CombatPlayer', self);
	currentCombatPlayer = 2;

	wExplorePlayer01 = Spawn(class'Wwise_Mms_Tactical_ExplorePlayer', self);
	wExplorePlayer02 = Spawn(class'Wwise_Mms_Tactical_ExplorePlayer', self);
	currentExplorePlayer = 2;

	eventPlayer = Spawn(class'Wwise_Mms_AkEventPlayer',self);

	BeginTacticalBuddy();

	if(!bAllMusicTransferred || !fullMusicDefinitionsListCompiled){	
		CompleteMusicDefs = CompileFullMusicDefinitionsList();
	}	

	nextCombatDefinition = GetRandomCombatDefinition();

	if(!nextCombatDefinition.WwiseEnabled){ //Line up the next combat definition if required.
		wCombatPlayer01.WwiseMms_InitCombatPlayer(nextCombatDefinition,xcomLastTurn);
	}

	nextExploreDefinition = GetRandomExploreDefinition();
			
	OnXComTurn();

	EvaluateTacticalMusicState();

	if(startedFromTransition
		||(soundManagerMessenger.PostTransitionDefinitionID != "")){ //If we have been handed a transition from skyranger we do that instead
		
		i = CompleteMusicDefs.Find(Name("MusicID"),Name(soundManagerMessenger.PostTransitionDefinitionID));

		if (i != -1){

			if(soundManagerMessenger.postTransitionSecondaryEvent != ""){

					PlayMusicEventFromPath(activeMusicDefinition,soundManagerMessenger.postTransitionSecondaryEvent);

			}else{

				nextExploreDefinition = CompleteMusicDefs[i];

				if(SquadIsConcealed() && nextExploreDefinition.ExploreConcealed_StartEventPath != ""){

					StartMusicDefinitionWithEvent(nextExploreDefinition,nextExploreDefinition.ExploreConcealed_StartEventPath);

				}else if(nextExploreDefinition.ExploreExposed_StartEventPath != ""){

					StartMusicDefinitionWithEvent(nextExploreDefinition,nextExploreDefinition.ExploreExposed_StartEventPath);
				}
				activeMusicDefinition = nextExploreDefinition;
			}

			nextExploreDefinition = GetRandomExploreDefinition();

			if(!nextExploreDefinition.WwiseEnabled){ //If the first explore definition will be an mms one then we need to get it cued up.
				wExplorePlayer01.WwiseMms_InitExplorePlayer(nextExploreDefinition);
			}

			`log("Wwise Mms transition found and played from strategy to tactical at DoMusicStart. Event Path is" @soundManagerMessenger.postTransitionSecondaryEvent);

			
			return; //Great! We transitioned!
		}
	}

	soundManagerMessenger.ResetValues();

	if(!inCombatMode){//Explore

		switch (nextExploreDefinition.WwiseEnabled){

			case true://Wwise Definition
															//Here we try to find a concealed 
				if(SquadIsConcealed() && nextExploreDefinition.ExploreConcealed_StartEventPath != ""){
					StartMusicDefinitionWithEvent(nextExploreDefinition,nextExploreDefinition.ExploreConcealed_StartEventPath);
				}else if(nextExploreDefinition.ExploreExposed_StartEventPath != ""){
					StartMusicDefinitionWithEvent(nextExploreDefinition,nextExploreDefinition.ExploreExposed_StartEventPath);
				}

				activeMusicDefinition = nextExploreDefinition;
				nextExploreDefinition = GetRandomExploreDefinition();

				break;

			case false://MMS definition

				wExplorePlayer01.WwiseMms_InitExplorePlayer(nextExploreDefinition);
				StartNextMusicDefinitionAndCycleLineup(true);	//This function assumes that the next mms player is already loaded, so we need to do that manually above.

				break;
			}

			if(!nextCombatDefinition.WwiseEnabled){ //If the first combat definition will be an mms one then we need to get it cued up.
					wCombatPlayer01.WwiseMms_InitCombatPlayer(nextCombatDefinition,true);
			}
		}

		KillDropship();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------DoEnvironmentAndMissionEvents
function DoEnvironmentAndMissionEvents(){

	local XComGameState_BattleData BattleData;
	local XComTacticalMissionManager missionManager;
	local XComEnvLightingManager lightingManager;
	local XComGameState_MissionSite MissionState;
	local int i;

	missionManager = XComTacticalMissionManager(class'Engine'.static.GetEngine().GetTacticalMissionManager());
	BattleData = XComGameState_BattleData(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	lightingManager = XComEnvLightingManager(class'Engine'.static.GetEngine().GetEnvLightingManager());
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom')).MissionRef.ObjectID));

	missionFamily = name(missionManager.ActiveMission.MissionFamily);
	if (missionFamily == ''){
		missionFamily = MissionState.GeneratedMission.Mission.MissionName;
	}
	timeOfDay = lightingManager.arrEnvironmentLightingDefs[XComEnvLightingManager(class'Engine'.static.GetEngine().GetEnvLightingManager()).currentMapIdx].ETimeOfDay;
	biome = name(BattleData.MapData.Biome);
	environment = name(`PARCELMGR.GetPlotDefinition(BattleData.MapData.PlotMapName).strType);

	/////
	i = activeMusicDefinition.Biome_EventPaths.Find('theName',biome);
	if(i != -1){
		PlayMusicEventFromPath(activeMusicDefinition,activeMusicDefinition.Biome_EventPaths[i].thePath);
	}

	i = activeMusicDefinition.Mission_EventPaths.Find('theName',missionFamily);
	if(i != -1){
		PlayMusicEventFromPath(activeMusicDefinition,activeMusicDefinition.Mission_EventPaths[i].thePath);
	}

	i = activeMusicDefinition.TimeOfDay_EventPaths.Find('theName',name(string(timeOfDay)));
	if(i != -1){
		PlayMusicEventFromPath(activeMusicDefinition,activeMusicDefinition.TimeOfDay_EventPaths[i].thePath);
	}

	i = activeMusicDefinition.Environment_EventPaths.Find('theName',environment);
	if(i != -1){
		PlayMusicEventFromPath(activeMusicDefinition,activeMusicDefinition.Environment_EventPaths[i].thePath);
	}
	/////
}



//-------------------------------------------------------------------------------------------------------------------------------------------------------------StartNextMusicDefinitionAndCycleLineup
function StartNextMusicDefinitionAndCycleLineup(bool explore){

	if(missionOver){return;}

	StopMMSPlayers();
	StopWwiseMmsPlayer();

	switch (explore){
		case true:				//Explore Code
			activeMusicDefinition = nextExploreDefinition;

			if (activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled){
				if(SquadIsConcealed() && activeMusicDefinition.ExploreConcealed_StartEventPath != ""){
					StartMusicDefinitionWithEvent(activeMusicDefinition,activeMusicDefinition.ExploreConcealed_StartEventPath);
				}else{
					StartMusicDefinitionWithEvent(activeMusicDefinition,activeMusicDefinition.ExploreExposed_StartEventPath);
				}
				`log("Wwise Mms attempting to play Wwise Definition" @nextExploreDefinition.MusicID);

			}else{

				if(currentExplorePlayer == 1){
					wExplorePlayer02.WwiseMms_Play();
					currentExplorePlayer = 2;
					`log("Wwise Mms Explore Player 2 attempting to play MMS definition" @nextExploreDefinition.MusicID);

				}else{

					wExplorePlayer01.WwiseMms_Play();
					currentExplorePlayer = 1;
					`log("Wwise Mms Explore Player 1 attempting to play MMS definition" @nextExploreDefinition.MusicID);
				}
			}

			nextExploreDefinition = GetRandomExploreDefinition();

			if (!nextExploreDefinition.WwiseEnabled){ //Prepare the next explore player if this is an MMS definition
				if(currentExplorePlayer == 1){
					wExplorePlayer02.WwiseMms_InitExplorePlayer(nextExploreDefinition);

				}else{
					wExplorePlayer01.WwiseMms_InitExplorePlayer(nextExploreDefinition);
				}
			}
		break;

		case false:				//Combat Code
			activeMusicDefinition = nextCombatDefinition;

			if (activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled){
				if(xcomLastTurn){
					StartMusicDefinitionWithEvent(activeMusicDefinition,activeMusicDefinition.XCombat_StartEventPath);
					`log("Wwise Mms attempting to play Wwise Definition" @nextExploreDefinition.MusicID);

				}else{

					if(activeMusicDefinition.ACombat_StartEventPath != ""){
						StartMusicDefinitionWithEvent(activeMusicDefinition,activeMusicDefinition.ACombat_StartEventPath);
						`log("Wwise Mms attempting to play Wwise Definition" @nextExploreDefinition.MusicID);

					}else{

						StartMusicDefinitionWithEvent(activeMusicDefinition,activeMusicDefinition.XCombat_StartEventPath);
						`log("Wwise Mms attempting to play Wwise Definition" @nextExploreDefinition.MusicID);
					}
				}

			}else{

				if(currentCombatPlayer == 1){
					wCombatPlayer02.WwiseMms_Play();
					currentCombatPlayer = 2;
					`log("Wwise Mms attempting to play combat MMS definition" @nextExploreDefinition.MusicID);

				}else{
					wCombatPlayer01.WwiseMms_Play();
					currentCombatPlayer = 1;
					`log("Wwise Mms attempting to play combat MMS definition" @nextExploreDefinition.MusicID);
				}
			}

			nextCombatDefinition = GetRandomCombatDefinition();

			if (!nextCombatDefinition.WwiseEnabled){ //Prepare the next combat player if this is an MMS definition
				if(currentCombatPlayer == 1){
					wCombatPlayer02.WwiseMms_InitCombatPlayer(nextCombatDefinition,xcomLastTurn);

				}else{

					wCombatPlayer01.WwiseMms_InitCombatPlayer(nextCombatDefinition,xcomLastTurn);
				}
			}
		break;
	}

	currentDefinitionTimer = 0;
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------EvaluateTacticalMusicState
function EvaluateTacticalMusicState(){

	local X2TacticalGameRuleset Ruleset;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState_Player LocalPlayerState;
	local XComGameState_Player PlayerState;
	local int wNumAlertedEnemiesPrevious;

	Ruleset = `TACTICALRULES;
	History = `XCOMHISTORY;

	

	`log("Wwise Mms Evaluating Tactical Music State");
	//Get the game state representing the local player
	LocalPlayerState = XComGameState_Player(History.GetGameStateForObjectID(Ruleset.GetLocalClientPlayerObjectID()));

	//Sync our internally tracked count of alerted enemies with the state of the game
	wNumAlertedEnemiesPrevious = wNumAlertedEnemies;
	wNumAlertedEnemies = 0;

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState){
		//Discover whether this unit is an enemy
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.GetAssociatedPlayerID()));

		if( PlayerState != none && LocalPlayerState.IsEnemyPlayer(PlayerState) ){
			//If the enemy unit is higher than green alert ( hunting or fighting ), 
			// Changed to only trigger on red alert.  Yellow alert can happen too frequently for cases of not being sighted. (Jumping through window, Protect Device mission)
			// Also, Terror missions the aliens are Stoping civilians while in green alert, this way combat music is purely a they have seen you case.

			//Get the currently visualized state for this unit ( so we don't read into the future )
			UnitState = XGUnit(UnitState.GetVisualizer()).GetVisualizedGameState();
			if( UnitState.IsAlive() && UnitState.GetCurrentStat(eStat_AlertLevel) > 1 ){
				++wNumAlertedEnemies;
			}
		}
	}

	if(wNumAlertedEnemiesPrevious > 0 && wNumAlertedEnemies == 0 ){	
		TransitionToExplore();
		`log("Wwise Mms Evaluation found transition to explore required.");

	}else if(wNumAlertedEnemiesPrevious == 0 && wNumAlertedEnemies > 0 ){
		`log("Wwise Mms Evaluation found transition to combat required.");
		TransitionToCombat();

		wNumCombatEvents++;
		if (wNumCombatEvents == 1){
			foreach History.IterateByClassType( class'XComGameState_Unit', UnitState ){
				if (XGUnit( UnitState.GetVisualizer( ) ).m_eTeam == eTeam_Neutral){
					XGUnit( UnitState.GetVisualizer( ) ).IdleStateMachine.CheckForStanceUpdate( );
				}
			}
		}
	}
}



//-------------------------------------------------------------------------------------------------------------------------------------------------------------PlayAfterActionMusic
function PlayAfterActionMusic(){

	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit UnitState;
	local bool bCasualties, bVictory;
	local int idx;
	local WwiseMms_AfterActionMusicDefinition definitionToPlay;
	local int winState;

	`log("Wwise Mms Tactical PlayAfterActionMusic called.");

	//StopSounds();
	StopWwiseMmsPlayer();
	StopMMSPlayers();

	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	bCasualties = false;

	soundManagerMessenger.ResetValues();

	if(BattleData != none){
		bVictory = BattleData.bLocalPlayerWon;
	}else{
		bVictory = XComHQ.bSimCombatVictory;
	}

	if(!bVictory){
		winState = 4;	

	}else{

		for(idx = 0; idx < XComHQ.Squad.Length; idx++){
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[idx].ObjectID));
			if(UnitState != none && UnitState.IsDead()){
				bCasualties = true;
				break;
			}
		}
		if(bCasualties){
			winState = 3;
		
		}else{
			winState = 1;
		}
	}

	definitionToPlay = GetRandomAfterActionDefinition(winState);

	if(definitionToPlay.MusicID != ''){	//Great, we have a transition!

		PlayAfterActionMusicDefinition(definitionToPlay, winState);

		`log("Wwise Mms playing transition into after action:" @definitionToPlay.MusicID);
		return;
	}

	`log("Wwise Mms reverting to  stock music for after action");
	PlayAkEvent(StartHQMusic); //We need to revert to the old behaviour if there is no custom music.
	switch (winState){
		case 1:
			SetSwitch('StrategyScreen', 'PostMissionFlow_FlawlessVictory');
			break;
		case 2:
		case 3:
			SetSwitch('StrategyScreen', 'PostMissionFlow_Pass');
			break;
		case 4:
			SetSwitch('StrategyScreen', 'PostMissionFlow_Fail');
			break;
	}

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------PlayAfterActionMusicDefinition
function PlayAfterActionMusicDefinition (WwiseMms_AfterActionMusicDefinition definitionToPlay, int winState){

	local Wwise_Mms_AkEventPlayer myPlayer;
	local string eventPath;
	local string nextPath;

	local string pathToBank;
	local AkEvent bankEvent;

	myPlayer = ObtainEventPlayer();

	switch (winState){
		case 1:
			eventPath = definitionToPlay.Append $ definitionToPlay.StartFlawless_EventPath;
			nextPath = definitionToPlay.StrategyStartFlawless_EventPath;
			break;
		case 2:
		case 3:
			eventPath = definitionToPlay.Append $ definitionToPlay.StartCasualties_EventPath;
			nextPath = definitionToPlay.StrategyStartCasualties_EventPath;
			break;
		case 4:
			eventPath = definitionToPlay.Append $ definitionToPlay.StartLoss_EventPath;
			nextPath = definitionToPlay.StrategyStartLoss_EventPath;
			break;
	}

	soundManagerMessenger.postTransitionEvent = nextPath;
	soundManagerMessenger.postTransitionDefinitionID = definitionToPlay.StrategyDefinition_MusicID;

	myPlayer.PlayMusicStartEventFromPath(eventPath, "");

	//Loading this bank into the transition manager partially resolves an issue with music stopping after the skyranger
	bankEvent = LoadEventFromPathSync(definitionToPlay.Append, nextPath);
	pathToBank = bankEvent.RequiredBank.Outer.Name $ "." $ bankEvent.RequiredBank.Name;
	soundManagerMessenger.transitionBank = AkBank(`CONTENT.RequestGameArchetype(pathToBank,,,false));
	`log("Wwise Mms loads bank to transition:" @pathToBank);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------GetRandomAfterActionMusic
function WwiseMms_AfterActionMusicDefinition GetRandomAfterActionDefinition(int winState){

	local WwiseMms_AfterActionMusicDefinition definitionToReturn;
	local WwiseMms_AfterActionMusicDefinition iDef;
	local array<int> idxs;
	local int i;
	local bool found;

	definitionToReturn.MusicID = '';
	found = false;

	if(AfterActionDefs.Length < 1 && AfterActionDefs[0].MusicID == ''){
		return definitionToReturn;
	}

	foreach AfterActionDefs(iDef,i){
		
		if(iDef.StrategyDefinition_MusicID == ""){
			continue;
		}

		switch (winState){
			case 1:
				if(iDef.StartFlawless_EventPath != "" && iDef.StrategyStartFlawless_EventPath != ""){
					idxs.AddItem(i);
					found = true;
				}
				break;
			case 2:
			case 3:
				
				if(iDef.StartCasualties_EventPath != "" && iDef.StrategyStartCasualties_EventPath != ""){
					idxs.AddItem(i);
					found = true;
				}
				break;
			case 4:
				if(iDef.StartLoss_EventPath != "" && iDef.StrategyStartLoss_EventPath != ""){
					idxs.AddItem(i);
					found = true;
				}
				break;
		}
	}

	if(found){
		definitionToReturn = AfterActionDefs[idxs[rand(idxs.Length)]];
	}
	return definitionToReturn;
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------StartEndBattleMusic
function StartEndBattleMusic(){

	StopMMSPlayers();
	PlayAfterActionMusic();
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------TransitionToExplore
function TransitionToExplore(){
	
	if(missionOver){return;}

	if (inCombatMode == true){

		if(activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled && currentDefinitionTimer < float(activeMusicDefinition.Lifespan)){

			if(activeMusicDefinition.XExplore_TransitionEventPath != ""){

				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.XExplore_TransitionEventPath);

			}else{

				StartNextMusicDefinitionAndCycleLineup(true);
			}

		}else{

			StartNextMusicDefinitionAndCycleLineup(true);
		}
	}

	inCombatMode = false;
	LastCommand = "TransitionToExplore";
	`log("Wwise Mms transitioning to explore.");
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------TransitionToCombat
function TransitionToCombat(){

	if(missionOver){return;}

	if (!inCombatMode){

		if(activeMusicDefinition.isAssigned && activeMusicDefinition.WwiseEnabled && currentDefinitionTimer < float(activeMusicDefinition.Lifespan)){ //If we are going to look for a transition...

			if(xcomLastTurn && activeMusicDefinition.XCombat_TransitionEventPath != ""){		//...and find an xcom turn transition that we are looking for...

				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.XCombat_TransitionEventPath);

			}else if(!xcomLastTurn && activeMusicDefinition.ACombat_TransitionEventPath != ""){//...and find an alien turn transition that we are looking for...

				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.ACombat_TransitionEventPath);
					
			}else if(activeMusicDefinition.XCombat_TransitionEventPath != ""){				//...and we didn't find an alien turn transition that we are looking for but there is an xcom turn transition...
				
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.XCombat_TransitionEventPath);

			}else{

				StartNextMusicDefinitionAndCycleLineup(false); //If we aren't transitioning, be chill and go to our lined up next one
			}

		}else{

			StartNextMusicDefinitionAndCycleLineup(false); //If we aren't transitioning, be chill and go to our lined up next one
		}
	}

	inCombatMode = true;
	LastCommand = "TransitionToCombat";
	`log("Wwise Mms transitioning to combat.");
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------OnXComTurn
function OnXComTurn(){

	if(missionOver){return;}

	SetState( 'TacticalGameTurn', 'XCOM' );
	SetSwitch( 'TacticalGameTurn', 'XCOM' );
	xcomLastTurn = true;
	wCombatPlayer01.OnNotifyTurnChange(true);
	wCombatPlayer02.OnNotifyTurnChange(true);


	if(activeMusicDefinition.WwiseEnabled){
		if(inCombatMode){
			if(activeMusicDefinition.XCombat_TransitionEventPath != ""){
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.XCombat_TransitionEventPath);
			}
		
		}else{

			if(SquadIsConcealed() && activeMusicDefinition.XExplore_Concealed_TransitionEventPath != ""){
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.XExplore_Concealed_TransitionEventPath);
			}else if(activeMusicDefinition.XExplore_TransitionEventPath != ""){
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.XExplore_TransitionEventPath);
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------OnAlienTurn
function OnAlienTurn(){

	if(missionOver){return;}

	SetState('TacticalGameTurn', 'Alien');
	SetSwitch('TacticalGameTurn', 'Alien');
	xcomLastTurn = false;
	wCombatPlayer01.OnNotifyTurnChange(false);
	wCombatPlayer02.OnNotifyTurnChange(false);

	if(activeMusicDefinition.WwiseEnabled){
		if(inCombatMode){
			if(activeMusicDefinition.ACombat_TransitionEventPath != ""){
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.ACombat_TransitionEventPath);
			}
		
		}else{

			if(SquadIsConcealed() && activeMusicDefinition.AExplore_Concealed_TransitionEventPath != "" ){
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.AExplore_Concealed_TransitionEventPath);
			}else if(activeMusicDefinition.AExplore_TransitionEventPath != ""){
				PlayMusicEventFromPath(activeMusicDefinition , activeMusicDefinition.AExplore_TransitionEventPath);
			}
		}
	}

	`log("Wwise Mms music definition timer is" @currentDefinitionTimer);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------GetRandomCombatDefinition
function WwiseMms_TacticalMusicDefinition GetRandomCombatDefinition(){

	local WwiseMms_TacticalMusicDefinition iDefinition;
	local array<WwiseMms_TacticalMusicDefinition> newSet;

	foreach CompleteMusicDefs(iDefinition){
		switch (iDefinition.WwiseEnabled){
			case true:
				if(iDefinition.XCombat_StartEventPath != "" 
				&& iDefinition.MusicID != activeMusicDefinition.MusicID){
					newSet.AddItem(iDefinition);		//Wwise Mms definitions with a combat entry point
				}
				break;

			case false:
				if (iDefinition.type){ //true = combat
					newSet.AddItem(iDefinition);		//Standard MMS combat definitions
				}
				break;
		}
	}

	return FindBestTacticalMusicDefinition(newSet);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------GetRandomExploreDefinition
function WwiseMms_TacticalMusicDefinition GetRandomExploreDefinition(){ //This doesn't check exposure level, it only looks for definitions with an exposed event

	local WwiseMms_TacticalMusicDefinition iDefinition;
	local array<WwiseMms_TacticalMusicDefinition> newSet;

	foreach CompleteMusicDefs(iDefinition){
		switch (iDefinition.WwiseEnabled){
			case true:
				if(iDefinition.ExploreExposed_StartEventPath != "" 
				&& iDefinition.MusicID != activeMusicDefinition.MusicID){
					newSet.AddItem(iDefinition);		//Wwise Mms definitions with an explore entry point
				}
				break;

			case false:
				if (!iDefinition.type){	//false = explore
					newSet.AddItem(iDefinition);		//Standard MMS explore definitions
				}
				break;
		}
	}

	return FindBestTacticalMusicDefinition(newSet);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------FindBestTacticalMusicDefinition
function WwiseMms_TacticalMusicDefinition FindBestTacticalMusicDefinition(array<WwiseMms_TacticalMusicDefinition> inDefinitions){

	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_MissionSite MissionState;
	local XComGameState_BattleData BattleData;
	local XComTacticalMissionManager missionManager;
	local XComEnvLightingManager lightingManager;

	local PlotDefinition PlotDef;

	missionManager = XComTacticalMissionManager(class'Engine'.static.GetEngine().GetTacticalMissionManager());
	BattleData = XComGameState_BattleData(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	lightingManager = XComEnvLightingManager(class'Engine'.static.GetEngine().GetEnvLightingManager());
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

	missionFamily = name(missionManager.ActiveMission.MissionFamily);
	if (missionFamily == ''){
		missionFamily = MissionState.GeneratedMission.Mission.MissionName;
	}
	timeOfDay = lightingManager.arrEnvironmentLightingDefs[XComEnvLightingManager(class'Engine'.static.GetEngine().GetEnvLightingManager()).currentMapIdx].ETimeOfDay;
	biome = name(BattleData.MapData.Biome);
	PlotDef = `PARCELMGR.GetPlotDefinition(BattleData.MapData.PlotMapName);
	nPlotSwitch = name(PlotDef.strType);
	bRain = `TACTICALRULES.bRain;
	
	MissionName = '';
	if (MissionState != none){
		MissionName = MissionState.GetMissionSource().DataName;
	}
	if (MissionState != none && MissionState.GetMissionSource().CustomMusicSet != ''){
		MissionName = MissionState.GetMissionSource().CustomMusicSet;
	}

	inDefinitions = ShuffleDefinitions(inDefinitions);

	if (!class'MMS_UISL_MCM'.default.bAllowFallback){
		InDefinitions.Sort(WwiseMms_ByFallback);
	}

	inDefinitions.Sort(WwiseMms_SortMissionSets);


	//PrintScoreList(inDefinitions);

	`log("Wwise Mms found" @ inDefinitions[0].MusicID @ "with a score of" @ WwiseMms_GetTMusicScore(inDefinitions[0]));

	return inDefinitions[0];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------WwiseMms_ShuffleTSets
function array<WwiseMms_TacticalMusicDefinition> ShuffleDefinitions(array<WwiseMms_TacticalMusicDefinition> inDefinitions){

	local int m;
	local int i;
	local WwiseMms_TacticalMusicDefinition iDef;

	m = InDefinitions.Length;

	while (m > 0){
		i = Rand(m);
		m--;
		iDef = inDefinitions[m];
		inDefinitions[m] = inDefinitions[i];
		inDefinitions[i] = iDef;
	}

	return inDefinitions;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------WwiseMms_ByFallback
function int WwiseMms_ByFallback(WwiseMms_TacticalMusicDefinition A, WwiseMms_TacticalMusicDefinition B){

	local bool AIsFallback;
	local bool BIsFallback;

	AIsFallback = FallbackIDs.Find(A.MusicID) != INDEX_NONE;
	BIsFallback = FallbackIDs.Find(B.MusicID) != INDEX_NONE;

	if (AIsFallback && !BIsFallback){
		return -1;
	}

	return 0;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------WwiseMms_SortMissionSets
function int WwiseMms_SortMissionSets(WwiseMms_TacticalMusicDefinition A, WwiseMms_TacticalMusicDefinition B){	

	return WwiseMms_GetTMusicScore(A) - WwiseMms_GetTMusicScore(B);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------WwiseMms_GetTMusicScore
function int WwiseMms_GetTMusicScore(WwiseMms_TacticalMusicDefinition entry){

	local int score;
	score = 0;
	
	if(entry.WwiseEnabled){
		
		// RAIN
																									 score += 1 << 2;	//no rain selection in Wwise for now, just do this;
			
		// BIOME
		if (entry.Biome_EventPaths.Find('theName',biome) != -1)										{score += 1 << 5;
		}else if (entry.PlayForAllBiomes)															{score += 1 << 4;
		}else																						{score += 1 << 3;
		}

		// ENVIRONMENT/PLOT
		if (entry.Environment_EventPaths.Find('theName',environment) != -1)							{score += 1 << 8;
		}else if (entry.PlayForAllEnvironments)														{score += 1 << 7;
		}else																						{score += 1 << 6;
		}

		// MISSION
		if (entry.Mission_EventPaths.Find('theName',missionFamily) != -1
		|| (class'MMS_UISL_MCM'.default.bMixInIndifferent && entry.PlayForAllMissions))				{score += 1 << 11;
		}else if (entry.PlayForAllMissions)															{score += 1 << 10;
		}else																						{score += 1 << 9;
		}

		return score;
	}


	//Only called for vanilla MMS definitions
	// RAIN
	if ((bRain && entry.EnvReq.rain == eRR_NoRain) 
	|| (!bRain && entry.EnvReq.rain == eRR_Rain))													{score += 1 << 0;
	}else if (entry.EnvReq.rain == eRR_Always)														{score += 1 << 1;
	}else																							{score += 1 << 2;
	}

	// BIOME
	if (entry.EnvReq.biome == nBiomeSwitch && nBiomeSwitch != '')									{score += 1 << 5;
	}else if (entry.EnvReq.biome == ''
	||	entry.EnvReq.biome == 'wildcard')															{score += 1 << 4;
	}else																							{score += 1 << 3;

	}

	// PLOT
	if (entry.EnvReq.plot == nPlotSwitch  && nPlotSwitch != '')										{score += 1 << 8;
	}else if (entry.EnvReq.plot == ''
	||	entry.EnvReq.plot == 'wildcard')															{score += 1 << 7;
	}else																							{score += 1 << 6;
	}

	// MISSION
	if ((entry.MissionMusicSet == MissionName && MissionName != '')
	|| (entry.MissionMusicSet == 'dlc' && DLCMissions.Find(MissionName) != INDEX_NONE) 
	|| (entry.MissionMusicSet == 'goldenpath' && GPMissions.Find(MissionName) != INDEX_NONE) 
	||	entry.MissionMusicSet == 'wildcard' 
	|| (class'MMS_UISL_MCM'.default.bMixInIndifferent && entry.MissionMusicSet == ''))				{score += 1 << 11;
	}else if (entry.MissionMusicSet == '')															{score += 1 << 10;
	}else																							{score += 1 << 9;
	}

	return score; //phew!
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------PrintScoreList
function PrintScoreList(array<WwiseMms_TacticalMusicDefinition> theList){

	local WwiseMms_TacticalMusicDefinition iDef;

	`log("----------------Wwise Mms Starting Tactical Score List----------------");
	foreach theList(iDef){
		`log(iDef.MusicID @"scored" @ WwiseMms_GetTMusicScore(idef));
	}
	`log("----------------Wwise Mms Finished Tactical Score List----------------");
}



//-------------------------------------------------------------------------------------------------------------------------------------------------------------PlayMusicEventFromPath
function PlayMusicEventFromPath(WwiseMms_TacticalMusicDefinition owningDefinition , string eventPath , optional bool newDefinition=false){

	local Wwise_Mms_AkEventPlayer myPlayer;
	local string endPath;

	endPath = "";

	if(owningDefinition.End_EventPath != ""){
		endPath = owningDefinition.Append $ owningDefinition.End_EventPath;
	}

	myPlayer = ObtainEventPlayer();

	if(newDefinition){
		myPlayer.PlayMusicStartEventFromPath(owningDefinition.Append $ eventPath, endPath);
	}else{
		myPlayer.PlayNonstartMusicEventFromPath(owningDefinition.Append $ eventPath);
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------StartMusicDefinitionWithEvent
function StartMusicDefinitionWithEvent(WwiseMms_TacticalMusicDefinition ownerDefinition, string eventPath){

	local string pathToBank;
	local AkEvent startEvent;
	
	startEvent = LoadEventFromPathSync(ownerDefinition.Append, eventPath);

	if(VeryWiseSoundBanks.Find(startEvent.RequiredBank) == -1){	//Loading in these banks resolves issues with them no playing at the end of the level.
		pathToBank = startEvent.RequiredBank.Outer.Name $ "." $ startEvent.RequiredBank.Name;
		`log("Wwise Mms loads bank" @pathToBank);
		`CONTENT.RequestObjectAsync(pathToBank, self, OnVeryWiseBankLoaded);
	}

	StopMMSPlayers();
	StopWwiseMmsPlayer();

	PlayMusicEventFromPath(ownerDefinition, eventPath, true);
	activeMusicDefinition = ownerDefinition;
	currentDefinitionTimer = 0.0f;

	DoEnvironmentAndMissionEvents();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------ObtainEventPlayer
function Wwise_Mms_AkEventPlayer ObtainEventPlayer(){
	
	if (eventPlayer != none){																			return eventPlayer;
	}

	eventPlayer = Spawn(class'Wwise_Mms_AkEventPlayer', self);							`log("Wwise Mms finds no event player! Creating...");
																										return eventPlayer;
}

//----------------------------------------------------------------------------------------------------------------------------LoadEventFromPathSync
function AkEvent LoadEventFromPathSync(string append, string path){

	local XComContentManager Mgr;

	Mgr = XComContentManager(class'Engine'.static.GetEngine().GetContentManager());

	if(path != ""){
		return AkEvent(Mgr.RequestGameArchetype(append $ path,,,false));
	}

	return none;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------CompileFullSetDefinitionList
function array<WwiseMms_TacticalMusicDefinition> CompileFullMusicDefinitionsList(){

	local TacticalMusic oldSet;
	local array<WwiseMms_TacticalMusicDefinition> newList;
	local name iName;
	local int i;

	WwiseMms_TransferAllMusic();

	newList = WiserTacticalMusicDefs;

	if(AllMusics.Length != 0){
		foreach AllMusics(oldSet){
			newList.AddItem(ConvertStandardSetDefinitionToWwiseMmsSetDefinition(oldSet));
		}
	}

	for (i = 0; i < newList.Length; i++){
		newList[i].isAssigned = true; 
	}

	`log("--------------------Wwise Mms Printing Tactical nonFallback List!--------------------");
	for (i = 0; i < newList.Length; i++){
		if(FallbackIDs.Find(newList[i].MusicID) == INDEX_NONE){
			`log(newList[i].MusicID);
		}
	}
	`log("--------------------Finished Printing Tactical nonFallback List!---------------------");


	`log("--------------------Wwise Mms Printing Tactical Fallback List!--------------------");
	foreach FallbackIDs(iName){
		`log(iName);
	}
	`log("--------------------Finished Printing Tactical Fallback List!---------------------");


	fullMusicDefinitionsListCompiled = true;

	return newList;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------WwiseMms_TransferAllMusic
function WwiseMms_TransferAllMusic(){
	
	local CombatMusicSet CSet;
	local ExploreMusic ESet;

	local TacticalMusic TSet;

	foreach CombatDefs(CSet)
	{
		TSet = GetEmptyTSet();
		TSet.ID = CSet.ID;
		TSet.type = true;
		TSet.MissionMusicSet = CSet.MissionMusicSet;
		TSet.EnvReq = CSet.EnvReq;
		TSet.Com = CSet;

		AllMusics.AddItem(TSet);
	}

	foreach ExploreDefs(ESet)
	{
		TSet = GetEmptyTSet();
		TSet.ID = ESet.ID;
		TSet.type = false;
		TSet.MissionMusicSet = ESet.MissionMusicSet;
		TSet.EnvReq = ESet.EnvReq;
		TSet.Exp = ESet;

		AllMusics.AddItem(TSet);
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------ConvertStandardSetDefinitionToWwiseMmsSetDefinition
function WwiseMms_TacticalMusicDefinition ConvertStandardSetDefinitionToWwiseMmsSetDefinition(TacticalMusic oldSet){

	local WwiseMms_TacticalMusicDefinition newDef;

	newDef.WwiseEnabled = false;

	newDef.MusicID = Name("Converted From MMS -" $ oldSet.ID $"-");
	newDef.type = oldSet.type;
	newDef.MissionMusicSet = oldSet.MissionMusicSet;
	newDef.EnvReq = oldSet.EnvReq;
	newDef.Exp = oldSet.Exp;
	newDef.Com = oldSet.Com;

	if (FallbackDefs.Find(oldSet.ID) != INDEX_NONE	 &&		FallbackIDs.Find(newDef.MusicID) == INDEX_NONE){
		FallbackIDs.AddItem(newDef.MusicID);
	}

	return newDef;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------StopMMSPlayers
function StopMMSPlayers(){

	if(currentCombatPlayer == 1){
		wCombatPlayer01.WwiseMms_StopMusic(true);
	}else{
		wCombatPlayer02.WwiseMms_StopMusic(true);
	}

	if(currentExplorePlayer == 1){
		wExplorePlayer01.WwiseMms_StopMusic();
	}else{	
		wExplorePlayer02.WwiseMms_StopMusic();
	}

}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------StopMMSPlayers
function StopWwiseMmsPlayer(){

	local Wwise_Mms_AkEventPlayer myPlayer;

	myPlayer = ObtainEventPlayer();
	myPlayer.StopMusic();
}


//-------------------------------------------------------------------------------------------------------------------------------------------------------------Cleanup
function Cleanup(){

	super.Cleanup();

	`log("Wwise Mms Tac cleaned up");

	wCombatPlayer01.Destroy();
	wCombatPlayer02.Destroy();
	wExplorePlayer01.Destroy();
	wExplorePlayer02.Destroy();
	eventPlayer.Destroy();
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------SquadIsConcealed
function bool SquadIsConcealed(){
	
	local XComGameStateHistory history;
	local XComGameState_Unit Unit;
	local bool isSquadConcealed;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();

	isSquadConcealed = true;

	foreach History.IterateByClassType(class'XComGameState_Unit', Unit){
		if (Unit.IsPlayerControlled() && Unit.IsSoldier()){
			if (!Unit.IsConcealed()){
				isSquadConcealed = false;
				break;
			}
		}
	}
	
	`log("Wwise Mms found SquadIsConcealed =" @isSquadConcealed);

	return isSquadConcealed;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
function PlayDropshipMusic(){														`log("MMS PlayDropshipMusic intercepted.");}
function ShuffleTSets(out array<TacticalMusic> InSets){								`log("MMS ShuffleTSets intercepted.");}
function int SortMissionSets(TacticalMusic A,TacticalMusic B){return 0;				`log("MMS SortMissionSets intercepted.");}
function int ByFallback(TacticalMusic A, TacticalMusic B){return 0;					`log("MMS ByFallback intercepted.");}
function int GetTMusicScore(TacticalMusic entry){return 0;							`log("MMS GetTMusicScore intercepted.");}
function TacticalMusic FindBestTacticalMusicSet(array<TacticalMusic> InSets){	
	local TacticalMusic dummy;														`log("MMS FindBestTacticalMusicSet intercepted."); 
	return dummy;
}

function TransferAllMusic(){														`log("MMS TransferAllMusic intercepted.");}
//function TacticalMusic GetEmptyTSet(){											
	//local TacticalMusic dummy;													`log("MMS GetEmptyTSet intercepted.");
	//return dummy;
//}

//These functions are how the game tells MMS that it wants something done, so we can't intercept them. This list not exhaustive.
//function StartEndBattleMusic(){													`log("MMS StartEndBattleMusic intercepted.");}
//function PlayAfterActionMusic(){													`log("MMS PlayAfterActionMusic intercepted.");}
//function SelectRandomTacticalMusicSet(){											`log("MMS SelectRandomTacticalMusicSet intercepted.");}
//function EvaluateTacticalMusicState(){											`log("MMS EvaluateTacticalMusicState intercepted.");}
//function TransitionToExplore(){													`log("MMS TransitionToExplore intercepted.");}
//function TransitionToCombat(){													`log("MMS TransitionToCombat intercepted.");}

defaultproperties
{
	fullMusicDefinitionsListCompiled = false
	missionOver = false
	startedFromTransition = false
	LastCommand = ""
	wNumAlertedEnemies = 0

	updatePeriod = 0.3f

	GPMissions(0)="MissionSource_BlackSite"
	GPMissions(1)="MissionSource_Forge"
	GPMissions(2)="MissionSource_PsiGate"
	GPMissions(3)="MissionSource_Broadcast"
	GPMissions(4)="Tutorial"
	GPMissions(5)="AlienFortress"

	DLCMissions(0)="DerelictFacility"
	DLCMissions(1)="LostTowerA"
	DLCMissions(2)="LostTowerB"
	DLCMissions(3)="LostTowerB_GasOn"
	DLCMissions(4)="LostTower_BossFight"
}