//---------------------------------------------------------------------------------------
//  File:	    Wwise_Mms_TacticalInformationFinder.uc
//  AUTHOR:		Adrian Hall --  2018
//  PURPOSE:	Base class for tactical buddy because UnrealScript doesn't support partials.
//---------------------------------------------------------------------------------------

class Wwise_Mms_TacticalInformationFinder extends Actor dependson(Wwise_Mms_XComTacticalSoundManager);

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetLivingEnemies
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


//------------------------------------------------------------------------------------------------------------------------------------------------------------GetVisibleEnemies
function int GetVisibleEnemies(optional out array<name> existingArray){
	
	local array<StateObjectReference>	VisibleUnits;
	local StateObjectReference			kObjRef;
	local XComGameState_Unit			UnitState;
	local array<name>					arrayToReturn;
	local int							count;

	count = 0;

	class'X2TacticalVisibilityHelpers'.static.GetAllVisibleEnemyUnitsForUnit(class'X2TacticalVisibilityHelpers'.static.GetPlayerFromTeamEnum(eTeam_XCom).ObjectID, VisibleUnits);

	foreach VisibleUnits(kObjRef){
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

//------------------------------------------------------------------------------------------------------------------------------------------------------------CountAlertedEnemies
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

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetDeadSoldiers
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

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetOverwatchingSoldiers
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

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetTurnsTaken
function int GetTurnsTaken(){
	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).PlayerTurnCount;
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------GetTurnsRemaining
function int GetTurnsRemaining(){

	local XComGameState_UITimer missionTimerUI;

	missionTimerUI = XComGameState_UITimer(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class 'XComGameState_UITimer', true));

	if(missionTimerUI.TimerValue <= 0){
		return 99;
	}
	return missionTimerUI.TimerValue;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetMissStreak
function int GetMissStreak(){
	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).MissStreak;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetHitStreak
function int GetHitStreak(){
	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).HitStreak;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetTurnsSinceEnemySeen
function int GetTurnsSinceEnemySeen(){
	return XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(`TACTICALRULES.GetLocalClientPlayerObjectID())).TurnsSinceEnemySeen;
}


//These are part of XComGameState_Player, could be useful
//var() Name				PlayerClassName;
//var() ETeam				TeamFlag;
//var() string			PlayerName;
//var() bool				bPlayerReady;       // Is the player sync'd and ready to progress?
//var() bool				bAuthority;
//var() bool				bSquadIsConcealed;	// While true, the entire squad for this player is considered concealed against the enemy player.
//var() int				SquadCohesion;      // Only relevant to single player XCom team
//var() int				TurnsSinceCohesion;
//var() array<name>       SoldierUnlockTemplates;
//var() int				SquadPointValue;
//var() bool              MicAvailable;
//var() string			SquadName;
//var() int		        MissStreak;
//var() int			    HitStreak;
//var() privatewrite int  TurnsSinceEnemySeen; // set to 0 when an enemy is seen 