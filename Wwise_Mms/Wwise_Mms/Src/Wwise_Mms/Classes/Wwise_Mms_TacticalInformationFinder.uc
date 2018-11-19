//---------------------------------------------------------------------------------------
//  FILE:	    Wwise_Mms_TacticalInformationFinder.uc
//  AUTHOR:		Adrian Hall --  2018
//  PURPOSE:	Contains functions for finding and analyzing information about the game
//					state in tactical mode.
//			 	Extended by Wwise_Mms_TacticalBuddy in an attempt to replicate partial 
//					class functionality within Unrealscript.
//---------------------------------------------------------------------------------------

class Wwise_Mms_TacticalInformationFinder extends Actor dependson(Wwise_Mms_XComTacticalSoundManager);

//-------------------------------------------------------------------------------------------------------GetLivingEnemies
//	Returns the number of living enemies on the map.
//	existingArray will be populated an entry for the name of each enemy type found.
//---------------------------------------------------------------------------------------------
function int GetLivingEnemies(optional out array<name> existingArray){
	
	local X2TacticalGameRuleset		Ruleset;
	local XComGameStateHistory		History;
	local XComGameState_Unit		UnitState;
	local XComGameState_Player		LocalPlayerState;
	local XComGameState_Player		PlayerState;
	local array<name>				arrayToReturn;
	local int						count;

	count = 0;
	Ruleset = `TACTICALRULES;
	History = `XCOMHISTORY;
	LocalPlayerState = XComGameState_Player(History.GetGameStateForObjectID(Ruleset.GetLocalClientPlayerObjectID()));

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState){
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.GetAssociatedPlayerID()));
		if(PlayerState != none && LocalPlayerState.IsEnemyPlayer(PlayerState)){
			UnitState = XGUnit(UnitState.GetVisualizer()).GetVisualizedGameState();
			if(UnitState.IsAlive()){	
				count++;
				if(arrayToReturn.Find(UnitState.GetMyTemplate().CharacterGroupName) == -1){														
					arrayToReturn.AddItem(UnitState.GetMyTemplate().CharacterGroupName);
				}
			}
		}
	}
	existingArray = arrayToReturn;
	return count;
}


//-------------------------------------------------------------------------------------------------------GetVisibleEnemies
//	Returns the number of enemies visible to the player.
//	existingArray will be populated an entry for the name of each enemy type found.
//---------------------------------------------------------------------------------------------
function int GetVisibleEnemies(optional out array<name> existingArray){
	
	local array<StateObjectReference>	visibleUnits;
	local StateObjectReference			kObjRef;
	local XComGameState_Unit			UnitState;
	local array<name>					arrayToReturn;
	local int							count;

	count = 0;
	
	//	visibleUnits is used as an out paramater and is populated with all enemies visible to the player.
	class'X2TacticalVisibilityHelpers'.static.GetAllVisibleEnemyUnitsForUnit(class'X2TacticalVisibilityHelpers'.static.GetPlayerFromTeamEnum(eTeam_XCom).ObjectID, visibleUnits);

	foreach visibleUnits(kObjRef){
		UnitState = XComGameState_Unit(class'XComGameStateHistory'.static.GetGameStateHistory().GetGameStateForObjectID(kObjRef.ObjectID));
		if (UnitState != None && UnitState.IsAlive() && UnitState.IsSpotted() && !UnitState.GetMyTemplate().bIsCosmetic){
			count++;
			if(arrayToReturn.Find(UnitState.GetMyTemplate().CharacterGroupName) == -1){														
				arrayToReturn.AddItem(UnitState.GetMyTemplate().CharacterGroupName);
			}
		}
	}

	existingArray = arrayToReturn;
	return count;
}

//-------------------------------------------------------------------------------------------------------GetAlertedEnemies
//	Returns the number of enemies on the map that are in an alerted state.
//---------------------------------------------------------------------------------------------
function int GetAlertedEnemies(optional out array<name> existingArray){

	local X2TacticalGameRuleset		Ruleset;
	local XComGameStateHistory		History;
	local XComGameState_Unit		UnitState;
	local XComGameState_Player		LocalPlayerState;
	local XComGameState_Player		PlayerState;
	local array<name>				arrayToReturn;
	local int						count;

	count = 0;

	Ruleset = `TACTICALRULES;
	History = `XCOMHISTORY;
	LocalPlayerState = XComGameState_Player(History.GetGameStateForObjectID(Ruleset.GetLocalClientPlayerObjectID()));

	//	Iterates through all units on the map.
	//	If a unit is a living enemy with eStat_Alertlevel higher than 1, the count is incrimented.
	//	That unit's name is added to arrayToReturn if it is not already there.
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState){
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.GetAssociatedPlayerID()));
		
		if(PlayerState != none && LocalPlayerState.IsEnemyPlayer(PlayerState)){
			UnitState = XGUnit(UnitState.GetVisualizer()).GetVisualizedGameState();
			
			if(UnitState.IsAlive() && UnitState.GetCurrentStat(eStat_AlertLevel) > 1 ){			
				count++;
				
				if(arrayToReturn.Find(UnitState.GetMyTemplate().CharacterGroupName) == -1){														
					arrayToReturn.AddItem(UnitState.GetMyTemplate().CharacterGroupName);
				}
			}
		}
	}

	existingArray = arrayToReturn;
	return count;
}

//-------------------------------------------------------------------------------------------------------GetDeadSoldiers
//	Returns the number of soldiers who have died during this mission.
//---------------------------------------------------------------------------------------------
function int GetDeadSoldiers(){

	local X2TacticalGameRuleset		Ruleset;
	local XComGameStateHistory		History;
	local XComGameState_Unit		UnitState;
	local XComGameState_Player		LocalPlayerState;
	local XComGameState_Player		PlayerState;
	local int						soldierCount;

	Ruleset = `TACTICALRULES;
	History = `XCOMHISTORY;
	LocalPlayerState = XComGameState_Player(History.GetGameStateForObjectID(Ruleset.GetLocalClientPlayerObjectID()));
	soldierCount = 0;

	//	Iterates through all units on the map.
	//	If a unit's PlayerState references matches the local client (the player), then it is a soldier.
	//	If a soldier is not alive then the count is incrimented.
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState){
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.GetAssociatedPlayerID()));
		
		if(PlayerState != none && LocalPlayerState == PlayerState){
			UnitState = XGUnit(UnitState.GetVisualizer()).GetVisualizedGameState();
			if(!UnitState.IsAlive()){			
				++soldierCount;
			}
		}
	}
	return soldierCount;
}

//-------------------------------------------------------------------------------------------------------GetOverwatchingSoldiers
//	Returns the number of soldiers currently on overwatch.
//---------------------------------------------------------------------------------------------
function int GetOverwatchingSoldiers(){

	local X2TacticalGameRuleset		Ruleset;
	local XComGameStateHistory		History;
	local XComGameState_Unit		UnitState;
	local XComGameState_Player		LocalPlayerState;
	local XComGameState_Player		PlayerState;
	local int						soldierCount;

	Ruleset = `TACTICALRULES;
	History = `XCOMHISTORY;
	LocalPlayerState = XComGameState_Player(History.GetGameStateForObjectID(Ruleset.GetLocalClientPlayerObjectID()));
	soldierCount = 0;
	
	//	Iterates through all units on the map.
	//	If a unit's PlayerState references matches the local client (the player), then it is a soldier.
	//	If a soldier has reserved action points, that is interpreted as overwatch and
	//		the counter is incremented.
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState){
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(UnitState.GetAssociatedPlayerID()));
		if(PlayerState != none && LocalPlayerState == PlayerState){
			UnitState = XGUnit(UnitState.GetVisualizer()).GetVisualizedGameState();
			if(UnitState.NumAllReserveActionPoints() > 0){			
				++soldierCount;
			}
		}
	}
	return soldierCount;
}

//-------------------------------------------------------------------------------------------------------GetTurnsTaken
//	Returns the number of completed turns so far this mission.
//---------------------------------------------------------------------------------------------
function int GetTurnsTaken(){

	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).PlayerTurnCount;
}


//-------------------------------------------------------------------------------------------------------GetTurnsRemaining
//	Returns the number of turns remaining on the mission timer (99 if there is no active timer).
//---------------------------------------------------------------------------------------------
function int GetTurnsRemaining(){

	local XComGameState_UITimer missionTimerUI;

	missionTimerUI = XComGameState_UITimer(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class 'XComGameState_UITimer', true));

	//	Countdown behaviour is  performed in kismet.
	//	The easiest way to get the turns remaining is to poll the timer UI itself.
	if(missionTimerUI.TimerValue <= 0){
		return 99;
	}
	
	return missionTimerUI.TimerValue;
}

//-------------------------------------------------------------------------------------------------------GetMissStreak
//	Returns the number of misses by XCOM since their last hit.
//---------------------------------------------------------------------------------------------
function int GetMissStreak(){

	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).MissStreak;
}

//-------------------------------------------------------------------------------------------------------GetHitStreak
//	Returns the number of hits by XCOM since their last miss.
//---------------------------------------------------------------------------------------------
function int GetHitStreak(){

	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).HitStreak;
}

//-------------------------------------------------------------------------------------------------------GetTurnsSinceEnemySeen
//	Returns the zero-based number of turns since an enemy last entered the field of view.
//---------------------------------------------------------------------------------------------
function int GetTurnsSinceEnemySeen(){

	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).TurnsSinceEnemySeen;
}