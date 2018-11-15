//---------------------------------------------------------------------------------------
//  FILE:		Wwise_Mms_StrategyBuddy.uc
//  AUTHOR:		Adrian Hall --  2018
//  PURPOSE:	Detects various events in strategy mode.
//				Sets RTPCs and passes initiates events from the active music definition in
//					Wwise_Mms_XComStrategySoundManager to the current AkEventPlayer.
//				Extends Wwise_Mms_StrategyInformationFinder in an attempt to replicate
//					partial class functionality in Unrealscript.
//---------------------------------------------------------------------------------------
class Wwise_Mms_StrategyBuddy extends Wwise_Mms_StrategyInformationFinder;

var bool scanning;
var bool flying;
var bool scanFinishDetected;

var int doomLevel;
var int facilityCount;
var int deadSoldierCount;
var int contactedRegionCount;

//-------------------------------------------------------------------------------------------------------Event - PostBeginPlay
//	Called once after gameplay begins.
//	Calls the super function.
//	Performs behaviour for number of dead soldiers (this never changes in strategy mode).
//---------------------------------------------------------------------------------------------
event PostBeginPlay(){

	super.PostBeginPlay();
	DoDeadSoldierCountCheck();
}

//-------------------------------------------------------------------------------------------------------Event - Tick
//	Called by the engine every frame.
//	Performs core class functionality if a Wwise Mms definition is currently active.
//	Checking every frame meaningfully improves responsiveness of music changes.
//---------------------------------------------------------------------------------------------
function Tick(float deltaTime){
	
	if(ActiveMusicDefinition().WwiseEnabled){
		PerformAllFrameByFrameChecks(); 
	}
}

//-------------------------------------------------------------------------------------------------------PerformAllFrameByFrameChecks
//	Batch function to check for all game state changes that require action.
// 	NOTE: performance could be marginally improved by moving functions that only apply in
//			geoscape to their own function set that isn't called in the base screen.
//---------------------------------------------------------------------------------------------
function PerformAllFrameByFrameChecks(){

	DoRoomCheck(); //Found in parent class.
	
	DoFacilityCountCheck();
	DoDoomLevelCheck();
	DoContactedRegionCountCheck();
	DoScanningCheck();
	DoFinishedScanningCheck();
	DoFlyingCheck();
}

//-------------------------------------------------------------------------------------------------------PerformCountValueBehaviour
//	Compares the current value of a variable with a new one and initiates any required RTPC
//		changes or AkEvent calls.
//	Must be handed either countArray or RTPCName to function.
// 	Capable of handling both a countArray and RTPCName in one call.
//---------------------------------------------------------------------------------------------
function PerformCountValueBehaviour(out int currentValue, int newValue, optional array<string> countArray, optional Name RTPCName,optional bool ignoreUnchangedForRTPCs = true){
	
	local string pathFound;
	
	//	If there is no difference between the current value and the new value then we
	//		shouldn't do anything unless we have been asked to update the RTPC regardless.
	if(newValue == currentValue){
		if(!ignoreUnchangedForRTPCs){
			SetRTPC(RTPCName,float(currentValue));
		}
		
		return;
	}

	currentValue = newValue;
	pathFound = GetBestStringFromCountArray(currentValue,countArray);

	// The functions below will simply do nothing if no countArray or RTPCName was given.
	if(pathFound != "" && pathFound != "IGNORE"){
		CallMusicEvent(ActiveMusicDefinition().Append $ pathFound);
	}

	SetRTPC(RTPCName,float(currentValue));
}

//-------------------------------------------------------------------------------------------------------DoDeadSoldierCountCheck
//	Calls PerformCountValueBehaviour() on the number of dead soldiers.
//---------------------------------------------------------------------------------------------
function DoDeadSoldierCountCheck(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(deadSoldierCount,CheckDeadSoldierCount(),ActiveMusicDefinition().DeadSoldierCount_EventPaths,'deadSoldiers',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoFacilityCountCheck
//	Calls PerformCountValueBehaviour() on the number of facilities that have been built.
//---------------------------------------------------------------------------------------------
function DoFacilityCountCheck(optional bool ignoreUnchangedForRTPCs = true){

	PerformCountValueBehaviour(facilityCount,CheckFacilityCount(),ActiveMusicDefinition().FacilityCount_EventPaths,'facilitiesConstructed',ignoreUnchangedForRTPCs);
}

//-------------------------------------------------------------------------------------------------------DoDoomLevelCheck
//	Calls PerformCountValueBehaviour() on the current doom level.
//---------------------------------------------------------------------------------------------
function DoDoomLevelCheck(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(doomLevel,CheckDoomLevel(),ActiveMusicDefinition().DoomLevel_EventPaths,'doomLevel',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @doomLevel @ "amount of doomedness.");
}


//-------------------------------------------------------------------------------------------------------DoContactedRegionCountCheck
//	Calls PerformCountValueBehaviour() on the number of regions that have been contacted.
//---------------------------------------------------------------------------------------------
function DoContactedRegionCountCheck(optional bool ignoreUnchangedForRTPCs = true){
	PerformCountValueBehaviour(contactedRegionCount,CheckContactedRegionCount(),ActiveMusicDefinition().ContactedRegionCount_EventPaths,'contactedRegions',ignoreUnchangedForRTPCs);
	//`log("wwise mms found" @contactedRegionCount @ "contacted regions.");
}

//-------------------------------------------------------------------------------------------------------DoScanningCheck
//	Checks if the skyranger is scanning a location on the geoscape.
//	Sets an RTPC and calls an event for the scanning status if required.
//	Uses a binary RTPC (100 for scanning, 0 for not scanning) in order to make some behaviour 
		more convenient to implement in Wwise.
//---------------------------------------------------------------------------------------------
function DoScanningCheck(){

	local bool newScanState;

	newScanState = CheckScanning();

	if(newScanState == scanning){
		return;
	}

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

//-------------------------------------------------------------------------------------------------------DoFinishedScanningCheck
//	Checks if The Avenger has completed a scan since this function was last called.
//---------------------------------------------------------------------------------------------
function DoFinishedScanningCheck(){

	local bool newScanState;
	
	//	The below returns unless the scan completion status has changed since the last check.
	newScanState = CheckFinishedScanning();
	
	if (scanFinishDetected == newScanState){
		return;
	}
	
	//	We are about to respond to the new scan state status.
	//	This records the state we are responding to so that the check above will work correctly.
	//	If a new scan has been started since the last one has completed, this is where
	//		scanFinishDetected will be set false.
	scanFinishDetected = newScanState;

	//	If we have detected that the scan has just been completed, this will check for and
	//		initiate the applicable event in the active music definition.
	if(scanFinishDetected && ActiveMusicDefinition().ScanningCompleted_EventPath != ""){
		CallMusicEvent(ActiveMusicDefinition().Append $ ActiveMusicDefinition().ScanningCompleted_EventPath);
	}
}

//-------------------------------------------------------------------------------------------------------DoFlyingCheck
//	Checks if the skyranger is flying over the geoscape.
//	Sets an RTPC and calls an event for the flying status if required.
//	Uses a binary RTPC (100 for flying, 0 for not flying) in order to make some behaviour 
		more convenient to implement in Wwise.
//---------------------------------------------------------------------------------------------
function DoFlyingCheck(){

	local bool newFlyingState;

	newFlyingState = CheckFlying();

	if(flying == newFlyingState){
		return;
	}

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


//-------------------------------------------------------------------------------------------------------OnRoomChangeDetected
//	Calls music events on a room change and maintains RTPCs using the names of adjacent rooms.
//	A complete list of room names can be found in the modding documentation.
//	Adjacency RTPCs are binary (100 for adjacent, 0 for not adjacent) and named "adjacentTo_NAME".
//---------------------------------------------------------------------------------------------
function OnRoomChangeDetected(name newRoom){

	local int eventIndex;
	local name iName;

																													`log("Wwise Mms detected entering" @newRoom);
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


//-------------------------------------------------------------------------------------------------------GetBestStringFromCountArray
//	Finds the highest index of seekArray which is at or below "value" and contains a non-empty string. 
//---------------------------------------------------------------------------------------------
function string GetBestStringFromCountArray(int value, array<string> seekArray){

	local int i;

	for(i = value; i >= 0; i--){
		if(seekArray[i] != ""){
			return seekArray[value];
		}
	}

	return "";
}

//-------------------------------------------------------------------------------------------------------CallMusicEvent
//	Gets the current AkEventPlayer from the sound manager and pass it an event path to play.
//---------------------------------------------------------------------------------------------
function CallMusicEvent(string eventPath){
	myBoss.ObtainEventPlayer().PlayNonstartMusicEventFromPath(eventPath);
}

//-------------------------------------------------------------------------------------------------------SetRTPC
//	Gets the current AkEventPlayer from the sound manager and sets an RTPC on it.
//---------------------------------------------------------------------------------------------
function SetRTPC(Name RTPCName, float newValue){										  
	myBoss.ObtainEventPlayer().SetRTPCValue(RTPCName, newValue);
}

//-------------------------------------------------------------------------------------------------------CallTrigger
//	Gets the current AkEventPlayer from the sound manager and calls a trigger on it.
//---------------------------------------------------------------------------------------------
function CallTrigger(Name triggerName){
	myBoss.ObtainEventPlayer().PostTrigger(triggerName);
}

//-------------------------------------------------------------------------------------------------------OnGeoscapeEnterDetected
//	DEPRECATED: Unsuccesful attempt at detecting shift to Geoscape at the start of the animation
//					to improve music responsiveness.
//---------------------------------------------------------------------------------------------
function OnGeoscapeEnterDetected(){

	if(ActiveMusicDefinition().WwiseEnabled){
		if(currentRoom	!= 'UIDisplayCam_CIC'){
			currentRoom = 'UIDisplayCam_CIC';
			myBoss.PlayGeoscapeMusic();
		}
	}
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