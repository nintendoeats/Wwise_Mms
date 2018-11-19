//---------------------------------------------------------------------------------------
//  FILE:	    Wwise_Mms_TacticalBuddy.uc
//  AUTHOR:		Adrian Hall -- 2018
//  PURPOSE:	Detects events in strategy mode which can triger optional Wwise Mms behaviour
//					but do not require a music definition change.
//				Extends Wwise_Mms_TacticalInformationFinder in an attempt to replicate
//					partial class functionality within Unrealscript.
//---------------------------------------------------------------------------------------

class Wwise_Mms_TacticalBuddy extends Wwise_Mms_TacticalInformationFinder dependson(Wwise_Mms_XComTacticalSoundManager);

enum UnitTeam{
	XCom,
	Civilian,
	Alien
};

var Wwise_Mms_XComTacticalSoundManager myBoss;   

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

var array<name> livingEnemyList;
var array<name> alertedEnemyList;
var array<name> visibleEnemyList;

var float iTimer;

var name activeMusicDefinitionID;


//-------------------------------------------------------------------------------------------------------State - Running
//	The kickstart function has been called and checks are active.
//---------------------------------------------------------------------------------------------
state Running{

	//-------------------------------------------------------------------------------------------------------Running - Begin
	//	Called when the "Running" state is first set.
	//	Executes DoAllCounts() every tenth of a second for 3 seconds.
	//---------------------------------------------------------------------------------------------
	Begin:
	
	//	This timer resolves the fact that non-vanilla RTPCs don't seem to take effect until
	//		a soundbank that uses them is actually being used.
	//	We want RTPCs to apply as early as possible, but load time is variable so we continually
	//		apply them for a few seconds.
	//	Eventually the system stops to save resources.
	
	iTimer = 0;
	
	while (iTimer < 3.0f){ 
		iTimer += 0.1f;
		Sleep(0.1f);
		DoAllCounts(false);
	}
}

//-------------------------------------------------------------------------------------------------------Kickstart
//	Executes some behaviour required to be run once before the object will work.
//	Changes state to "Running".
//---------------------------------------------------------------------------------------------
function Kickstart(){

																											`log("Wwise Mms started tactical buddy!");
	RegisterForEvents();
	DoAllCounts(false);
	GoToState('Running');
}

//-------------------------------------------------------------------------------------------------------Tick
//	Executes behaviour required to be performed frequently by the tactical buddy.
//	Calls PerformAllFrameByFrameChecks() if a Wwise Mms definition is playing.
//	If the active music definitions has changed , calls DoAllEnemyTypeListUpdates(), calls DoAllCounts() 
//		and sets activeMusicDefinitionID to the new definition.
//	Not to be confused with the event "tick" which is called by the game engine.
//---------------------------------------------------------------------------------------------
function Tick( float deltaTime){
	
	if(activeMusicDefinition().WwiseEnabled){
		PerformAllFrameByFrameChecks();
	}

	if(ActiveMusicDefinition().MusicID != activeMusicDefinitionID){
		DoAllEnemyTypeListUpdates();
		DoAllcounts();
		activeMusicDefinitionID = ActiveMusicDefinition().MusicID;
	}
}

//-------------------------------------------------------------------------------------------------------PerformAllFrameByFrameChecks
//	Calls some functions which update variables and initiate Wwise Mms behaviour if required.
//	Only calls functions which could change on any frame and need to be constantly updated.
//---------------------------------------------------------------------------------------------
function PerformAllFrameByFrameChecks(){
	
	DoVisibleEnemyCount();
	DoAlertedEnemyCount();
	DoOverwatchingSoldierCount();
	DoTurnsSinceEnemySeenCount();
	DoHitStreakCount();
	DoMissStreakcount();	
}

//-------------------------------------------------------------------------------------------------------DoAllCounts
//	Calls all functions which update variables and initiate Wwise Mms behaviour if required.
//	Should not be called every frame as some of these variables will only change under known
//		circumstances.
//	If ignoreUnchangedForRTPCs is false then only RTPCs have not already been set to the 
//		correct value will be set by Wwise Mms.
//---------------------------------------------------------------------------------------------
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

//-------------------------------------------------------------------------------------------------------DoAllEnemyTypeListUpdates
//	Obtains one array of names for all living enemies, one for all alerted enemies and one 
//		for all visible enemies.
//	Calls DoEnemyTypeList() on each of the three arrays.
//---------------------------------------------------------------------------------------------
function DoAllEnemyTypeListUpdates(){
	
	local array<name> procLivingEnemies;
	local array<name> procAlertedEnemies;
	local array<name> procVisibleEnemies;
	
	GetLivingEnemies(procLivingEnemies);
	GetAlertedEnemies(procAlertedEnemies);
	GetVisibleEnemies(procVisibleEnemies);

	DoEnemyTypeList(livingEnemyList,procLivingEnemies,ActiveMusicDefinition().LivingEnemyType_TrueEventPaths,ActiveMusicDefinition().LivingEnemyType_FalseEventPaths,"living_");
	DoEnemyTypeList(alertedEnemyList,procAlertedEnemies,ActiveMusicDefinition().AlertedEnemyType_TrueEventPaths,ActiveMusicDefinition().AlertedEnemyType_FalseEventPaths,"alerted_");
	DoEnemyTypeList(visibleEnemyList,procVisibleEnemies,ActiveMusicDefinition().VisibleEnemyType_TrueEventPaths,ActiveMusicDefinition().VisibleEnemyType_FalseEventPaths, "visible_");
}


//-------------------------------------------------------------------------------------------------------DoEnemyTypeList
//	Sets RTPCs and calls events based on compared lists of names (intended to be the names of enemies).
//	runningList will be compared with, and replaced by, foundList.
//	If a name exists in foundList but not runningList, an RTPC called [RTPCPrefix][name] will
//		be set to 100.
//	If that name also appears in startEventList then the event at the associated path will be called.
//	If a name exists in runningList but not foundList, an RTPC called [RTPCPrefix][name] will
//		be set to 0.
//	If that name also appears in endEventList then the event at the associated path will be called.
//	All event calls are performed in the order they were found and after all RTPCs have been set.
//---------------------------------------------------------------------------------------------
function DoEnemyTypeList(out array<name> runningList, array<name> foundList, array<NameAndPath> startEventList, array<NameAndPath> endEventList, string RTPCPrefix){
	
	local array<name>	oldList;
	local array<string> eventList;
	local name			iName;
	local string		iString;
	local int			i;
	
	//	runningList is immediately updated with the values from foundList and its original values stored in oldList.
	//	Remember that if modifying this function!
	oldList = runningList;
	runningList = foundList;
	
	//	This checks for any names which were on our list and no longer are.
	//	RTPCs for those names are set and an event is called if applicable.
	foreach oldList(iName){
		i = endEventList.Find('theName',iName);

		if(runningList.Find(iName) == -1){ 
			SetRTPC(name(RTPCPrefix $ string(iName)),0.0);
			if(i != -1){
				eventList.AddItem(endEventList[i].thePath);
			}
		}
	}

	//	This checks for any names which are on our list but were not before.
	//	RTPCs for those names are set and an event is called if applicable.
	foreach runningList(iName){
		i = startEventList.Find('theName',iName);

		if(oldList.Find(iName) == -1){
			SetRTPC(name(RTPCPrefix $ string(iName)),100.0);
			if(i != -1){
				eventList.AddItem(startEventList[i].thePath);
			}
		}
	}

	//	Call any events that we found while cycling through the lists.
	foreach eventList(iString){
		CallMusicEvent(ActiveMusicDefinition().Append $ iString);
	}

}

//-------------------------------------------------------------------------------------------------------PerformCountValueBehaviour
//	Sets RTPCs and calls an event from countArray based on newValue if one is found.
//	currentValue and countArray are passed to GetBestStringFromCountArray() and the path returned
//		is called as a Wwise event unless it is "" or "IGNORE".
//	If no RTPCname is passed then no RTPC will be set.
//	currentValue will be set to newValue.
//---------------------------------------------------------------------------------------------
function PerformCountValueBehaviour(out int currentValue, int newValue, optional array<string> countArray, optional Name RTPCName = '',optional bool ignoreUnchangedForRTPCs = true){
	
	local string pathFound;

	if(newValue == currentValue){
		if(!ignoreUnchangedForRTPCs && RTPCName != ''){
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

//-------------------------------------------------------------------------------------------------------GetBestStringFromCountArray
//	Returns the first string non-empty found in seekArray, counting from startIndex down.
//---------------------------------------------------------------------------------------------
function string GetBestStringFromCountArray(int startIndex, array<string> seekArray){

	local int i;
	
	if(seekArray.Length > 1 || seekArray[0] != ""){
		for(i = startIndex; i >= 0; i--){
			if(seekArray[i] != ""){
				return seekArray[i];
			}
		}
	}

	return "";
}

//-------------------------------------------------------------------------------------------------------DoLivingEnemyCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of living enemies.
//---------------------------------------------------------------------------------------------
function DoLivingEnemyCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(livingEnemies,GetLivingEnemies(), activeMusicDefinition().LivingEnemyCount_EventPaths,'livingEnemies',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoVisibleEnemyCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of visible enemies.
//---------------------------------------------------------------------------------------------
function DoVisibleEnemyCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(visibleEnemies,GetVisibleEnemies(), activeMusicDefinition().VisibleEnemyCount_EventPaths,'visibleEnemies',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoAlertedEnemyCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of alerted enemies.
//---------------------------------------------------------------------------------------------
function DoAlertedEnemyCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(alertedEnemies,GetAlertedEnemies(), activeMusicDefinition().AlertedEnemyCount_EventPaths,'alertedEnemies',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoDeadSoldierCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of dead soldiers.
//---------------------------------------------------------------------------------------------
function DoDeadSoldierCount(optional bool ignoreUnchangedForRTPCs = true){	

	PerformCountValueBehaviour(deadSoldiers,GetDeadSoldiers(), activeMusicDefinition().DeadSoldierCount_EventPaths,'deadSoldiers',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoOverwatchingSoldierCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of overwatching soldiers.
//---------------------------------------------------------------------------------------------
function DoOverwatchingSoldierCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(overwatchingSoldiers,GetOverwatchingSoldiers(),activeMusicDefinition().OverwatchingSoldierCount_EventPaths,'overwatchingSoldiers',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoTurnsTakenCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the zero-based number of turns so far.
//---------------------------------------------------------------------------------------------
function DoTurnsTakenCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(turnsTaken,GetTurnsTaken(),activeMusicDefinition().TurnsTakenCount_EventPaths,'turnsTaken',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoTurnTimerCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the current turn timer value.
//---------------------------------------------------------------------------------------------
function DoTurnTimerCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(turnsRemaining,GetTurnsRemaining(),activeMusicDefinition().TurnsRemainingCount_EventPaths,'turnsRemaining',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoTurnsSinceEnemySeenCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the zero-based number of turns
//		since an enemy was last seen by the player.
//---------------------------------------------------------------------------------------------
function DoTurnsSinceEnemySeenCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(turnsSinceEnemySeen,GetTurnsSinceEnemySeen(),activeMusicDefinition().TurnsSinceEnemySeenCount_EventPaths,'turnsSinceEnemySeen',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoHitStreakCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of hits by XCOM
//		soldiers since their last miss.
//---------------------------------------------------------------------------------------------
function DoHitStreakCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(hitStreak,GetHitStreak(),activeMusicDefinition().HitStreakCount_EventPaths,'hitStreak',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoHitStreakCount
//	Calls PerformCountValueBehaviour with appropriate parameters on the number of misses by XCOM
//		soldiers since their last hit.
//---------------------------------------------------------------------------------------------
function DoMissStreakCount(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(missStreak,GetMissStreak(),activeMusicDefinition().MissStreakCount_EventPaths,'missStreak',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoScamperStarted
//	Sets an RTPC and calls an event (if activeMusicDefinition specifies one) for when alerted enemies
//		have entered field of view and make their initial moves.
//---------------------------------------------------------------------------------------------
function DoScamperStarted(){

	if(ActiveMusicDefinition().ScamperStarted_EventPath != ""){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().ScamperStarted_EventPath);
	}
	SetRTPC('alienScamper',100.0f);
}

//-------------------------------------------------------------------------------------------------------DoScamperEnded
//	Sets an RTPC and calls an event (if activeMusicDefinition specifies one) for when scampering enemies
//		have finished their initial moves.
//---------------------------------------------------------------------------------------------
function DoScamperEnded(){

	if(ActiveMusicDefinition().ScamperFinished_EventPath != ""){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().ScamperFinished_EventPath);
	}
	SetRTPC('alienScamper',0.0f);
}

//-------------------------------------------------------------------------------------------------------PostUnitDamage
//	Sets the RTPC "lastSoldierDamage", "lastCivilianDamage" or "lastAlienDamage".
//---------------------------------------------------------------------------------------------
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

//-------------------------------------------------------------------------------------------------------PostUnitUnconscious
//	Calls the Wwise trigger "SoldierUnconscious", "CivilianUnconscious" or "AlienUnconscious".
//---------------------------------------------------------------------------------------------
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

//-------------------------------------------------------------------------------------------------------PostUnitDeath
//	Calls the Wwise trigger "SoldierDeath", "CivilianDeath" or "AlienDeath".
//	Calls DoDeadSoldierCount() or DoLivingEnemyCount() as required.
//---------------------------------------------------------------------------------------------
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


//-------------------------------------------------------------------------------------------------------ActiveMusicDefinition
//	Returns the active music definition from the tactical sound manager.
//---------------------------------------------------------------------------------------------
function WwiseMms_TacticalMusicDefinition ActiveMusicDefinition(){	
														  
	return myBoss.activeMusicDefinition;	
}

//-------------------------------------------------------------------------------------------------------InCombatMode
//	Returns whether or not the tactical sound manager is in combat mode.
//---------------------------------------------------------------------------------------------
function bool InCombatMode(){																							   	 
	return myBoss.inCombatMode;	
}

//-------------------------------------------------------------------------------------------------------CallMusicEvent
//	Gets the AkEvent player object and gives it an event path to play.
//	"Append" string from the active music definition must already have been added to the path.
//---------------------------------------------------------------------------------------------
function CallMusicEvent(string eventPath){

	myBoss.ObtainEventPlayer().PlayNonstartMusicEventFromPath(eventPath);
}

//-------------------------------------------------------------------------------------------------------SetRTPC
//	Gets the AkEvent player object and gives it an RTPC to set.
//---------------------------------------------------------------------------------------------
function SetRTPC(Name RTPCName, float newValue){		
													  
	myBoss.ObtainEventPlayer().SetRTPCValue(RTPCName, newValue);
}

//-------------------------------------------------------------------------------------------------------CallTrigger
//	Gets the AkEvent player object and gives it a Wwise trigger name to activate.
//---------------------------------------------------------------------------------------------
function CallTrigger(Name triggerName){

	myBoss.ObtainEventPlayer().PostTrigger(triggerName);
}


//-------------------------------------------------------------------------------------------------------RegisterForEvents
//	Registers this object for all of the events which will be used to activate Wwise Mms behaviour.
//---------------------------------------------------------------------------------------------
function RegisterForEvents(){

	local X2EventManager EventManager;
	local Object thisObject;

	EventManager = class'X2EventManager'.static.GetEventManager();
	
	//	Self cannot be an out parameter, so we need to store a normal reference to it.
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
	
	//	These events are not currently used by Wwise Mms, but may be useful for future iterations.
	
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

//-------------------------------------------------------------------------------------------------------Event - OnScamperStart
//	Called when alerted enemies	have entered field of view and make their initial moves.
//	Calls DoScamperStarted.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnScamperStart(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	DoScamperStarted();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnScamperEnd
//	Called when scampering enemies have finished their initial moves.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnScamperEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	DoScamperEnded();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnPlayerTurnBegin
//	Called when the player's turn starts.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnPlayerTurnBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	DoTurnTimerCount();
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnPlayerTurnEnd
//	Called when the player's turn ends.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnPlayerTurnEnd(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	DoTurnTimerCount();
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnEffectBreakUnitConcealment
//	Called when one or more units break concealment.
//	Sets the Wwise trigger 'UnitBreaksConcealment'.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnEffectBreakUnitConcealment(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	CallTrigger('UnitBreaksConcealment');
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnEffectEnterUnitConcealment
//	Called when one or more units enter concealment.
//	Sets the Wwise trigger 'UnitEntersConcealment'.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnEffectEnterUnitConcealment(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	CallTrigger('UnitEntersConcealment');
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnRankUpMessage
//	Called when the player is informed that a soldier will gain a rank after the mission.
//	Sets the Wwise trigger 'RankUp'.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnRankUpMessage(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	CallTrigger('RankUp');
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnUnitDied
//	Called when any unit on the map dies.
//	The unit's team is found and passed to PostUnitDeath().
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnUnitDied(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	local ETeam unitAlliance; 

	unitAlliance = XComGameState_Unit(EventSource).GetTeam();
	PostUnitDeath(unitAlliance);
	
	DoAllEnemyTypeListUpdates();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnObjectiveCompleted
//	Called when any objective is completed.
//	There are no Wwise Mms behaviours for objective completion.
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnObjectiveCompleted(Object EventData, Object EventSource, XComGameState GameState, Name EventID){

	//	Completing this objective may have altered the turn timer, so this needs to be checked right away.
	DoTurnTimerCount();
	return ELR_NoInterrupt;
}

//-------------------------------------------------------------------------------------------------------Event - OnUnitTookDamage
//	Called when any unit on the map takes damage.
//	Does nothing if the unit dies, otherwise calls either PostUnitDamage() or PostUnitUnconscious().
//---------------------------------------------------------------------------------------------
function EventListenerReturn OnUnitTookDamage(Object EventData, Object EventSource, XComGameState GameState, Name EventID){
	
	//	The behaviour in this event should be moved to its own function for consistency with other events.
	
	local XComGameState_Unit damagee;
	local bool damageeWasKilled;
	local bool damageeUnconscious;

	local ETeam unitAlliance; 
	local float damageDone;
	local UnitValue LastEffectDamage;
	local bool unitValueSuccess;

	damagee = XComGameState_Unit(EventSource);
	unitValueSuccess = damagee.GetUnitValue('LastEffectDamage',LastEffectDamage);
	
	damageeWasKilled = damagee.IsDead();
	damageeUnconscious = damagee.IsUnconscious();
	damageDone = LastEffectDamage.fValue; 

	unitAlliance = damagee.GetTeam();

	//the core logic
	if(damageeWasKilled){ 
		//	If the unit is killed then that is handled in its own event. 
		//	This check merely prevents the damage function from doing anything else.
		
	}else if(damageeUnconscious){
	
		PostUnitUnconscious(unitAlliance);
		
	}else{
	
		PostUnitDamage(unitAlliance,damageDone);
	}
	

	return ELR_NoInterrupt;
}

