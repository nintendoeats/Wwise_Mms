//---------------------------------------------------------------------------------------
//  FILE:		Wwise_Mms_StrategyBuddy.uc
//  AUTHOR:		Adrian Hall --  2018
//  PURPOSE:	Detects non-track-changing events in the strategy screen and reports them to the music player
//---------------------------------------------------------------------------------------
class Wwise_Mms_StrategyBuddy extends Wwise_Mms_StrategyInformationFinder;

var bool scanning;
var bool flying;
var bool scanFinishDetected;

var int doomLevel;
var int facilityCount;
var int deadSoldierCount;
var int contactedRegionCount;

//------------------------------------------------------------------------------------------------------------------------------------------------------------PostBeginPlay
event PostBeginPlay(){

	super.PostBeginPlay();
	DoDeadSoldierCountCheck();
}

////------------------------------------------------------------------------------------------------------------------------------------------------------------PreBeginPlay
//event PreBeginPlay(){
//
	//super.PreBeginPlay();
	//class'Engine'.static.GetCurrentWorldInfo().WorldInfo.RemoteEventListeners.AddItem(self);
//}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnRemoteEvent
//event OnRemoteEvent(name remoteEventName){
	//
	//super.OnRemoteEvent(RemoteEventName);
	//`log("Wwise Mms notified of" @remoteEventName);
//
	//if(remoteEventName == 'CIN_TransitionToMap'){
		//OnGeoscapeEnterDetected();
	//}
//}

//------------------------------------------------------------------------------------------------------------------------------------------------------------Tick
function Tick( float deltaTime){
	
	if(ActiveMusicDefinition().WwiseEnabled){//No point in doing any of this if we are playing an MMS definition.
		PerformAllFrameByFrameChecks(); 
	}
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------PerformAllFrameByFrameChecks
function PerformAllFrameByFrameChecks(){

	//Some of these should come out of frame by frame and at lease be limited to geoscape or baseview
	DoRoomCheck();
	DoFacilityCountCheck();

	DoScanningCheck();
	DoFinishedScanningCheck();
	DoFlyingCheck();
	DoDoomLevelCheck();
	DoContactedRegionCountCheck();
}



//------------------------------------------------------------------------------------------------------------------------------------------------------------DoScanningCheck
function DoScanningCheck(){

	local bool newScanState;

	newScanState = CheckScanning();

	if(newScanState == scanning){
		return;
	}
	//myBoss.PlayTestNoise();
	scanning = newScanState;

	if(scanning){	
		lastScanSite = GetHeadquarters().GetCurrentScanningSite(); //Very important that this gets set on a new scan location for the finished scanning check to work
		if(ActiveMusicDefinition().StartScanning_EventPath != ""){
			CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().StartScanning_EventPath);
		}
		SetRTPC('geoScanning',100.0);
		return;
	}
	if(!scanning){	
		if(ActiveMusicDefinition().StopScanning_EventPath != ""){
			CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().StopScanning_EventPath);
		}
		SetRTPC('geoScanning',0.0);
		return;
	}

}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoFinishedScanningCheck
function DoFinishedScanningCheck(){

	local bool newScanState;

	newScanState = CheckFinishedScanning();
	if (scanFinishDetected == newScanState){
		return;
	}

	scanFinishDetected = newScanState;

	if(scanFinishDetected && ActiveMusicDefinition().ScanningCompleted_EventPath != ""){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().ScanningCompleted_EventPath);
		//myBoss.PlayTestNoise();
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoFlyingCheck
function DoFlyingCheck(){

	local bool newFlyingState;

	newFlyingState = CheckFlying();

	if(flying == newFlyingState){
		return;
	}

	//myBoss.PlayTestNoise();
	flying = newFlyingState;

	if(flying){	
		if(ActiveMusicDefinition().StartFlying_EventPath != ""){
			CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().StartFlying_EventPath);
		}
		SetRTPC('geoflying',100.0);
		return;
	}
	if(!flying){	
		if(ActiveMusicDefinition().StopFlying_EventPath != ""){
			CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().StopFlying_EventPath);
		}
		SetRTPC('geoflying',0.0);
		return;
	}

}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoFacilityCountCheck
function DoFacilityCountCheck(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(facilityCount,CheckFacilityCount(),ActiveMusicDefinition().FacilityCount_EventPaths,'facilitiesConstructed',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @facilityCount @ "facilities.");
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------DoDoomCheck
function DoDoomLevelCheck(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(doomLevel,CheckDoomLevel(),ActiveMusicDefinition().DoomLevel_EventPaths,'doomLevel',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @doomLevel @ "amount of doomedness.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoDeadSoldierCountCheck
function DoDeadSoldierCountCheck(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(deadSoldierCount,CheckDeadSoldierCount(),ActiveMusicDefinition().DeadSoldierCount_EventPaths,'deadSoldiers',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @deadSoldierCount @ "dead soldiers.");
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoContactedRegionCountCheck
function DoContactedRegionCountCheck(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(contactedRegionCount,CheckContactedRegionCount(),ActiveMusicDefinition().ContactedRegionCount_EventPaths,'contactedRegions',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @contactedRegionCount @ "contacted regions.");
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------ActiveMusicDefinition
function OnRoomChangeDetected(name newRoom){

	//This expects a cleaned room name! Doesn't really matter, but that's how it should be used.
	local int eventIndex;
	local name iName;

	`log("Wwise Mms detected entering" @newRoom);
	//myBoss.PlayTestNoise();
	eventIndex = ActiveMusicDefinition().Room_EventPaths.Find('theName',newRoom);

	if(eventIndex != -1){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().Room_EventPaths[eventIndex].thePath);
	}else{
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().UnsupportedRoom_EventPath);
	}

	foreach previousAdjacentRooms(iName){
		if(adjacentRooms.Find(iName) == -1){
			SetRTPC(name("adjacentTo_" $ iName),0);
		}
	}

	if(adjacentRooms[0] != ''){
		foreach adjacentRooms(iName){
			SetRTPC(name("adjacentTo_" $ iName),100);
			`log("Wwise Mms finds adjacent room" @iName);
		}
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GeoscapeEnterDetected
function OnGeoscapeEnterDetected(){

	if(ActiveMusicDefinition().WwiseEnabled){
		`log("Wwise Mms doing early geoscape.");
		if(currentRoom	!= 'UIDisplayCam_CIC'){
			currentRoom = 'UIDisplayCam_CIC';
			myBoss.PlayTestNoise();
			myBoss.PlayGeoscapeMusic();
		}
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------PerformCountValueBehaviour
function PerformCountValueBehaviour(out int currentValue, int newValue, optional array<string> countArray, optional Name RTPCName,optional bool ignoreUnchangedForRTPCs = true){
	
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

	SetRTPC(RTPCName,float(currentValue));

}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetEventPathFromCountArray
function string GetBestStringFromCountArray(int value, array<string> seekArray){

	local int i;

	for(i = value; i >= 0; i--){
		if(seekArray[i] != ""){
			return seekArray[value];
		}
	}

	return "";
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------CallMusicEvent
function CallMusicEvent(string eventPath){
	myBoss.ObtainEventPlayer().PlayNonstartMusicEventFromPath(eventPath);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------SetRTPC
function SetRTPC(Name RTPCName, float newValue){										  
	myBoss.ObtainEventPlayer().SetRTPCValue(RTPCName, newValue);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------CallTrigger
function CallTrigger(Name triggerName){
	myBoss.ObtainEventPlayer().PostTrigger(triggerName);
}

defaultproperties
{
	scanning = false
	flying = false
	scanFinishDetected = false

	doomLevel = -1
	facilityCount = -1
	deadSoldierCount = -1
	contactedRegionCount = -1
}