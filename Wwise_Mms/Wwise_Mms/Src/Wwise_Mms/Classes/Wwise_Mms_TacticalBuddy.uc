//---------------------------------------------------------------------------------------
//  FILE:	    Wwise_Mms_TacticalBuddy.uc
//  AUTHOR:		Adrian Hall -- 2018
//  PURPOSE:	Detects non-track-changing events in the strategy screen and reports them to the music player
//---------------------------------------------------------------------------------------
class Wwise_Mms_TacticalBuddy extends Wwise_Mms_TacticalInformationFinder dependson(Wwise_Mms_XComTacticalSoundManager);

enum UnitTeam{
	XCom,
	Civilian,
	Alien
};

var Wwise_Mms_XComTacticalSoundManager myBoss;   
 
 //Here are all of our counts
var int livingEnemies;
var int visibleEnemies;
var int alertedEnemies;

var int deadSoldiers;
var int overwatchingSoldiers;

var int turnsTaken;
var int turnsRemaining;
var int turnsSinceEnemySeen;

var int hitStreak;
var int missStreak;

var float iTimer;

var array<name> livingEnemyList;
var array<name> alertedEnemyList;
var array<name> visibleEnemyList;

var name activeMusicDefinitionID;


//event OnActiveUnitChanged(XComGameState_Unit NewActiveUnit); //It would be cool to detect if the current enemy is concealed

//------------------------------------------------------------------------------------------------------------------------------------------------------------Kickstart
function Kickstart(){

	`Log("Wwise Mms started tactical buddy!");

	RegisterForEvents();
	DoAllCounts(false);
	GoToState('Running');
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------state - Running
state Running
{	
	Begin:
	//	This timer resolves the fact that non-vanilla RTPCs won't take until the event is actually playing.
	//	We want it to apply as early as possible but load time is variable, so we do it for a few seconds.
	//	Eventually the system stops to save resources. Except the ones in Tick obviously...
	iTimer = 0;
	while (iTimer < 3.0f){ 
		iTimer += 0.1f;
		Sleep(0.1f);
		DoAllCounts(false);
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------Tick
function Tick( float deltaTime){
	
	if(activeMusicDefinition().WwiseEnabled){//No point in doing any of this if we are playing an MMS definition.
		PerformAllFrameByFrameChecks();
	}

	if(ActiveMusicDefinition().MusicID != activeMusicDefinitionID){ //We need to redo some things when the music definition changes
		DoAllEnemyTypeListUpdates();
		DoAllcounts();
		activeMusicDefinitionID = ActiveMusicDefinition().MusicID;
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------PerformAllFrameByFrameChecks
function PerformAllFrameByFrameChecks(){
	
	DoVisibleEnemyCount();
	DoAlertedEnemyCount();
	DoOverwatchingSoldierCount();

	DoTurnsSinceEnemySeenCount();

	DoHitStreakCount();
	DoMissStreakcount();
	
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoLivingEnemyCount
function DoAllCounts(optional bool ignoreUnchangedForRTPCs = true){
	
	DoLivingEnemyCount(ignoreUnchangedForRTPCs);
	DoVisibleEnemyCount(ignoreUnchangedForRTPCs);
	DoAlertedEnemyCount(ignoreUnchangedForRTPCs);
	DoDeadSoldierCount(ignoreUnchangedForRTPCs);
	DoOverwatchingSoldierCount(ignoreUnchangedForRTPCs);
	DoTurnsTakenCount(ignoreUnchangedForRTPCs);
	DoTurnTimerCount(ignoreUnchangedForRTPCs);
	DoHitStreakCount(ignoreUnchangedForRTPCs);
	DoMissStreakcount(ignoreUnchangedForRTPCs);
	DoTurnsSinceEnemySeenCount(ignoreUnchangedForRTPCs);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoEnemyListUpdates
function DoAllEnemyTypeListUpdates(){
	
	local array<name> procLivingEnemies;
	local array<name> procAlertedEnemies;
	local array<name> procVisibleEnemies;
	
	GetLivingEnemies(procLivingEnemies);
	GetAlertedEnemies(procAlertedEnemies);
	GetVisibleEnemies(procVisibleEnemies);

	DoEnemyTypeList(livingEnemyList,procLivingEnemies,ActiveMusicDefinition().LivingEnemyType_TrueEventPaths,ActiveMusicDefinition().LivingEnemyType_FalseEventPaths,"living_");
	DoEnemyTypeList(alertedEnemyList,procAlertedEnemies,ActiveMusicDefinition().AlertedEnemyType_TrueEventPaths,ActiveMusicDefinition().LivingEnemyType_FalseEventPaths,"alerted_");
	DoEnemyTypeList(visibleEnemyList,procVisibleEnemies,ActiveMusicDefinition().VisibleEnemyType_TrueEventPaths,ActiveMusicDefinition().LivingEnemyType_FalseEventPaths, "visible_");
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------DoEnemyTypeList
function DoEnemyTypeList(out array<name> staticList, array<name> processingList, array<NameAndPath> startEventList, array<NameAndPath> endEventList, string RTPCPrefix){
	
	local array<name>	oldList;
	local array<string> eventList;
	local name			iName;
	local string		iString;
	local int			i;

	oldList = staticList;
	staticList = processingList;
	
	foreach oldList(iName){

		i = endEventList.Find('theName',iName);

		if(staticList.Find(iName) == -1){ //If this enemy type is not in our new list of enemies...
			if(i != -1){
				SetRTPC(name(RTPCPrefix $ string(iName)),0.0);
				eventList.AddItem(endEventList[i].thePath);
			}
		}
	}

	foreach staticList(iName){

		i = startEventList.Find('theName',iName);

		if(oldList.Find(iName) == -1){
			SetRTPC(name(RTPCPrefix $ string(iName)),100.0);
			if(i != -1){
				eventList.AddItem(startEventList[i].thePath);
			}
		}
	}

	foreach eventList(iString){
		CallMusicEvent(ActiveMusicDefinition().Append $ iString);
	}

}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoScamperStarted
function DoScamperStarted(){
	if(ActiveMusicDefinition().ScamperStarted_EventPath != ""){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().ScamperStarted_EventPath);
	}
	SetRTPC('alienScamper',100.0f);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoScamperFinished
function DoScamperEnded(){
	if(ActiveMusicDefinition().ScamperFinished_EventPath != ""){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().ScamperFinished_EventPath);
	}
	SetRTPC('alienScamper',0.0f);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoLivingEnemyCount
function DoLivingEnemyCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(livingEnemies,GetLivingEnemies(), activeMusicDefinition().LivingEnemyCount_EventPaths,'livingEnemies',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @livingEnemies @ "living enemies.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoVisibleEnemyCount
function DoVisibleEnemyCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(visibleEnemies,GetVisibleEnemies(), activeMusicDefinition().VisibleEnemyCount_EventPaths,'visibleEnemies',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @visibleEnemies @ "visible enemies.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoAlertedEnemyCount
function DoAlertedEnemyCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(alertedEnemies,GetAlertedEnemies(), activeMusicDefinition().AlertedEnemyCount_EventPaths,'alertedEnemies',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @alertedEnemies @ "alerted enemies.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoDeadSoldierCount
function DoDeadSoldierCount(optional bool ignoreUnchangedForRTPCs = true){	
	PerformCountValueBehaviour(deadSoldiers,GetDeadSoldiers(), activeMusicDefinition().DeadSoldierCount_EventPaths,'deadSoldiers',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @deadSoldiers @ "dead soldiers.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoOverwatchingSoldierCount
function DoOverwatchingSoldierCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(overwatchingSoldiers,GetOverwatchingSoldiers(),activeMusicDefinition().OverwatchingSoldierCount_EventPaths,'overwatchingSoldiers',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @overwatchingSoldiers @ "soldiers in overwatch.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoTurnsTakenCount
function DoTurnsTakenCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(turnsTaken,GetTurnsTaken(),activeMusicDefinition().TurnsTakenCount_EventPaths,'turnsTaken',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @turnsTaken @ "turns taken so far.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoTurnTimerCount
function DoTurnTimerCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(turnsRemaining,GetTurnsRemaining(),activeMusicDefinition().TurnsRemainingCount_EventPaths,'turnsRemaining',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @turnsRemaining @ "turns remaining.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoTurnsSinceEnemySeenCount
function DoTurnsSinceEnemySeenCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(turnsSinceEnemySeen,GetTurnsSinceEnemySeen(),activeMusicDefinition().TurnsSinceEnemySeenCount_EventPaths,'turnsSinceEnemySeen',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @turnsSinceEnemySeen @ "turns since enemy seen.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoHitStreakCount
function DoHitStreakCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(hitStreak,GetHitStreak(),activeMusicDefinition().HitStreakCount_EventPaths,'hitStreak',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @hitStreak @ "hit streak.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoMissStreakCount
function DoMissStreakCount(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(missStreak,GetMissStreak(),activeMusicDefinition().MissStreakCount_EventPaths,'missStreak',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @missStreak @ "miss streak.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------PerformCountValueBehaviour
function PerformCountValueBehaviour(out int currentValue, int newValue, optional array<string> countArray, optional Name RTPCName = '',optional bool ignoreUnchangedForRTPCs = true){
	
	local string pathFound;

	if(newValue == currentValue){
		if(!ignoreUnchangedForRTPCs){
			SetRTPC(RTPCName,float(currentValue));
		}
		return;
	}

	currentValue = newValue;
	pathFound = GetBestStringFromCountArray(currentValue,countArray);

	if(pathFound != "" && pathFound != "IGNORE"){
		CallMusicEvent(ActiveMusicDefinition().Append $ pathFound);
	}

	if(RTPCName != ''){
		SetRTPC(RTPCName,float(currentValue));
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetEventPathFromCountArray
function string GetBestStringFromCountArray(int value, array<string> seekArray){

	local int i;
	if(seekArray.Length > 1 || seekArray[0] != ""){
		for(i = value; i >= 0; i--){
			if(seekArray[i] != ""){
				return seekArray[value];
			}
		}
	}

	return "";
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnPlayerTurnBegin
function EventListenerReturn OnPlayerTurnBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	DoTurnTimerCount();
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnScamperStart
function EventListenerReturn OnScamperStart(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	DoScamperStarted();
	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnScamperEnd
function EventListenerReturn OnScamperEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	DoScamperEnded();
	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnPlayerTurnEnd
function EventListenerReturn OnPlayerTurnEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	DoTurnTimerCount();
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnEffectBreakUnitConcealment
function EventListenerReturn OnEffectBreakUnitConcealment(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	CallTrigger('UnitBreaksConcealment');
	DoAllEnemyTypeListUpdates();

	`log("Wwise Mms triggers UnitBreaksConcealment");

	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnEffectEnterUnitConcealment
function EventListenerReturn OnEffectEnterUnitConcealment(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	CallTrigger('UnitEntersConcealment');
	DoAllEnemyTypeListUpdates();

	`log("Wwise Mms triggers UnitEntersConcealment");

	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnRankUpMessage
function EventListenerReturn OnRankUpMessage(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	CallTrigger('RankUp');
	`log("Wwise Mms triggers RankUp");

	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnUnitDied
function EventListenerReturn OnUnitDied(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	local ETeam unitAlliance; 

	`log("wwise mms Informed of unit death.");

	unitAlliance = XComGameState_Unit(EventSource).GetTeam();

	DoAllEnemyTypeListUpdates();

	PostUnitDeath(unitAlliance);

	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnObjectiveCompleted
function EventListenerReturn OnObjectiveCompleted(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	`log("wwise mms Informed of objective completion");
	DoTurnTimerCount();

	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnUnitTookDamage
function EventListenerReturn OnUnitTookDamage(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	
	local XComGameState_Unit damagee;
	//local XComGameState_Unit damager;
	//local XComGameStateContext_Ability AbilityContext;
	local bool damageeWasKilled;
	local bool damageeUnconscious;
	//local XComGameStateHistory History;

	local ETeam unitAlliance; 
	local float damageDone;
	local UnitValue LastEffectDamage;
	local bool unitValueSuccess;

	//History = class'XComGameStateHistory'.static.GetGameStateHistory();
	//AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	damagee = XComGameState_Unit(EventSource);
	unitValueSuccess = damagee.GetUnitValue('LastEffectDamage',LastEffectDamage);

	`Log("Wwise Mms unit value success is" @unitValueSuccess);

	//if( AbilityContext != None ){
		//damager = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
	//}
	
	damageeWasKilled = damagee.IsDead();
	damageeUnconscious = damagee.IsUnconscious();
	damageDone = LastEffectDamage.fValue; 

	unitAlliance = damagee.GetTeam();
	`Log("Wwise Mms detected damage to unit on team" @ unitAlliance);

	//the core logic
	if(damageeWasKilled){ 
		//this situation is now handled in its own event. We don't want damage to conflict with it though, so we do nothing.
	}else if(damageeUnconscious){
		PostUnitUnconscious(unitAlliance);
	}else{
		PostUnitDamage(unitAlliance,damageDone);
		`Log("Wwise Mms detected" @damageDone @"damage dealt.");
	}
	

	return ELR_NoInterrupt;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------PostUnitDamage
function PostUnitDamage(ETeam unitAlliance,float damage){

	switch(unitAlliance){
		case eTeam_XCom:
		CallTrigger('SoldierDamaged');
		SetRTPC('lastSoldierDamage',damage);
		break;
		case eTeam_Neutral:
		CallTrigger('CivilianDamaged');
		SetRTPC('lastCivilianDamage',damage);
		break;
		case eTeam_Alien:
		CallTrigger('AlienDamaged');
		SetRTPC('lastAlienDamage',damage);
		break;
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------PostUnitDamage
function PostUnitUnconscious(ETeam unitAlliance){

	switch(unitAlliance){
		case eTeam_XCom:
		CallTrigger('SoldierUnconscious');
		break;
		case eTeam_Neutral:
		CallTrigger('CivilianUnconscious');
		break;
		case eTeam_Alien:
		CallTrigger('AlienUnconscious');
		break;
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------PostUnitDeath
function PostUnitDeath(ETeam unitAlliance){

	switch(unitAlliance){
		case eTeam_XCom:
			CallTrigger('SoldierDeath');
			DoDeadSoldierCount();
		break;
		case eTeam_Neutral:
			CallTrigger('CivilianDeath');
		break;
		case eTeam_Alien:
			CallTrigger('AlienDeath');
			DoLivingEnemyCount();

		break;
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------ActiveMusicDefinition
function WwiseMms_TacticalMusicDefinition ActiveMusicDefinition(){															  
	return myBoss.activeMusicDefinition;	
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------InCombatMode
function bool InCombatMode(){																							   	 
	return myBoss.inCombatMode;	
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------CallMusicEvent
function CallMusicEvent(string eventPath){

	myBoss.ObtainEventPlayer().PlayNonstartMusicEventFromPath(eventPath);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------SetRTPC
function SetRTPC(Name RTPCName, float newValue){		
													  
	myBoss.ObtainEventPlayer().SetRTPCValue(RTPCName, newValue);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------SetRTPC
function CallTrigger(Name triggerName){
	myBoss.ObtainEventPlayer().PostTrigger(triggerName);
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------RegisterForEvents
function RegisterForEvents(){

	local X2EventManager EventManager;
	local Object thisObject; //Yes you need to use this instead of self. Self cannot be an out parameter.

	EventManager = class'X2EventManager'.static.GetEventManager();
	thisObject = self;

	EventManager.RegisterForEvent(thisObject, 'UnitTakeEffectDamage', OnUnitTookDamage, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(thisObject, 'EffectBreakUnitConcealment', OnEffectBreakUnitConcealment, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(thisObject, 'EffectEnterUnitConcealment', OnEffectEnterUnitConcealment, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(ThisObject, 'RankUpMessage', OnRankUpMessage, ELD_OnStateSubmitted);
	EventManager.RegisterForEvent(ThisObject, 'UnitDied', OnUnitDied, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(ThisObject, 'PlayerTurnBegun', OnPlayerTurnBegin, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(ThisObject, 'PlayerTurnEnded', OnPlayerTurnEnd, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(ThisObject, 'MissionObjectiveMarkedCompleted', OnObjectiveCompleted, ELD_OnVisualizationBlockCompleted);
	EventManager.RegisterForEvent(ThisObject, 'ScamperBegin', OnScamperStart, ELD_OnVisualizationBlockStarted);
	EventManager.RegisterForEvent(ThisObject, 'ScamperBegin', OnScamperEnd, ELD_OnVisualizationBlockCompleted);
	//EventManager.RegisterForEvent(ThisObject, 'UnitAttacked', OnUnitAttacked, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'MissionObjectiveMarkedFailed', OnChallengeObjectiveFailed, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'SpawnReinforcementsComplete', OnSpawnReinforcementsComplete, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'UnitBleedingOut', OnUnitDiedOrBleedingOut, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'ObjectHacked', OnObjectHacked, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'UnitEvacuated', OnUnitEvacuated, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'UnitIcarusJumped', OnUnitIcarusJumped, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, 'LootDropCreated', OnLootDropCreated, ELD_OnStateSubmitted);
	//EventManager.RegisterForEvent(ThisObject, DiedWithParthenogenicPoisonTriggerName, OnUnitDiedWithParthenogenicPoison, ELD_OnStateSubmitted);
}

