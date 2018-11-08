//---------------------------------------------------------------------------------------
//  FILE:    Wwise_Mms_StrategyInformationFinder.uc
//  AUTHOR:  Adrian Hall --  2018
//  PURPOSE: Base class for Strategy buddy because UnrealScript doesn't support partials.
//---------------------------------------------------------------------------------------
class Wwise_Mms_StrategyInformationFinder extends Actor 
dependson(Wwise_Mms_XComStrategySoundManager)  dependson(XComGameState_HeadquartersXCom) dependson(XComGameState_FacilityXCom) dependson(XComGameState_HeadquartersRoom);

var	name currentRoom;
var int currentMapIndex;
var	array<name> adjacentRooms;

var	name previousRoom;
var	array<name> previousAdjacentRooms;

var Wwise_Mms_XComStrategySoundManager myBoss;
var XComGameState_ScanningSite lastScanSite;



//------------------------------------------------------------------------------------------------------------------------------------------------------------DoRoomCheck
function DoRoomCheck(){

	local name roomType;
	local array<name> newAdjacencyArray;

	if(HQCam().CurrentRoom == currentRoom){
		return;
	}

	previousRoom = currentRoom;
	currentRoom = HQCam().CurrentRoom;

	roomType = GetRoomTypeFromLocationName(currentRoom, currentMapIndex);

	previousAdjacentRooms = adjacentRooms;

	if(currentMapIndex != -1){
		newAdjacencyArray = GetAdjacentRoomTypes(currentMapIndex);
	}

	adjacentRooms = newAdjacencyArray;

	OnRoomChangeDetected(GetRoomTypeFromLocationName(roomType));

}

//------------------------------------------------------------------------------------------------------------------------------------------------------------CheckScanning
function bool CheckScanning(){
	
	return XComHeadquartersGame(class'Engine'.static.GetCurrentWorldInfo().Game).GetGamecore().GetGeoscape().IsScanning();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------CheckFinishedScanning
function bool CheckFinishedScanning(){
	if(lastScanSite == none){
		return false;
	}
	 return lastScanSite.IsScanComplete();
}

//class'X2EventManager'.static.GetEventManager().TriggerEvent('ScanStarted', ScanSiteState, , NewGameState); If there were a 'scan finished' event I would use this instead...

//------------------------------------------------------------------------------------------------------------------------------------------------------------CheckFlying
function bool CheckFlying(){

	local XComGameState_HeadquartersXCom theAvenger;
	
	theAvenger = GetHeadquarters();

	if(theAvenger.LiftingOff || theAvenger.Flying){ //Counting the landing state as landed is better for music transitions
		return true;
	}

	return false;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DoomLevel
function int CheckDoomLevel(){

	return class'UIUtilities_Strategy'.static.GetAlienHQ().GetCurrentDoom();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DeadSoldiers
function int CheckDeadSoldierCount(){

	return class'UIUtilities_Strategy'.static.GetXComHQ().DeadCrew.Length;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------DeadSoldiers
function int CheckFacilityCount(){

	local int count;

	count = class'UIUtilities_Strategy'.static.GetXComHQ().Facilities.Length;
	count -= 7;
	//`log("Wwise Mms detects number of facilities:" @count);
	return count;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetAdjacentRoomTypes
function array<name> GetAdjacentRoomTypes(int mapIndex){

	local XComGameState_HeadquartersRoom roomToTest;
	local XComGameState_HeadquartersRoom iRoom;
	local StateObjectReference iRef;
	local array<name> arrayToReturn;

	if(mapIndex == -1){
		return arrayToReturn;
	}

	roomToTest = GetHeadquarters().GetRoom(mapIndex);

	foreach roomToTest.AdjacentRooms(iRef){
		iRoom = XComGameState_HeadquartersRoom(`XCOMHISTORY.GetGameStateForObjectID(iRef.ObjectID));
		arrayToReturn.AddItem(iRoom.GetFacility().GetMyTemplateName());
	}

	`Log("Wwise mms found" @arrayToReturn.Length @"adjacent rooms.");

	return arrayToReturn;
}


//------------------------------------------------------------------------------------------------------------------------------------------------------------GetRoomTypeFromLocationName
function name GetRoomTypeFromLocationName(name roomName, optional out int mapIndex){

	local int row;
	local int column;
	local array<string> nameBreakdown;
	local name nameToReturn;

	`log("Wwise Mms parsing room location" @roomName);

	nameBreakdown = SplitString(string(roomName),"_",true);

	mapIndex = -1;
	nameToReturn = roomName;

	if(nameBreakdown[0] == "AddonCam"){ //This is a grid room.
		row = int(Right(nameBreakdown[1],1));
		column = int(Right(nameBreakdown[2],1));
		mapIndex = ConvertGridLocationToMapIndex(row,column);
		`Log("Wwise mms room found map index" @mapindex @"From grid reference" @row @"," @column);
		nameToReturn = GetHeadquarters().GetRoom(mapIndex).GetFacility().GetMyTemplateName();
	}

	if(nameBreakdown[0] == "UIDisplayCam"){ //This is a static room.
		nameToReturn = name(nameBreakdown[1]);
	}

	if(nameBreakdown[0] == "UIBlueprint"){
		nameToReturn = name(nameBreakdown[1]);
	}

	if(nameBreakdown[1] == "UIDisplayCam"){ //This is probably squad select.
		nameToReturn = name(nameBreakdown[2]);
	}

	if(nameToReturn == 'PowerCore'){
		nametoReturn = 'Research';
	}

	if(nameToReturn == 'Storage'|| nameToReturn == 'BuildItems'){
		nametoReturn = 'Engineering';
	}

	if(nameToReturn == 'Armory' || nameToReturn == 'ArmoryMenu' || nameToReturn == 'Promotion' || nameToReturn == 'Loadout' || nameToReturn == 'CustomizeMenu' || nameToReturn == 'PromotionInjured'){
		nametoReturn = 'Hangar';
	}

	return nameToReturn;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------ConvertGridLocationToMapIndex
function int ConvertGridLocationToMapIndex(int row, int column){

	local int mapIndex;

	mapIndex = (row * 3);	//Start with the base zero row
	mapIndex += column - 1;		//Add the base zero column

	return mapIndex;

	//This is the code we are undoing above.
	//if (RoomStateObject.MapIndex >= 3 && RoomStateObject.MapIndex <= 14){
		//GridIndex = RoomStateObject.MapIndex - 3;
		//RoomRow = (GridIndex / 3) + 1;
		//RoomColumn = (GridIndex % 3) + 1;
		//CameraName = "AddonCam" $ "_R" $ RoomRow $ "_C" $ RoomColumn;
	//}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------CheckContactedRegionCount
function int CheckContactedRegionCount(){

	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local int i;

	i = 0;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();

	foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState){
		if(RegionState.ResistanceLevel >= eResLevel_Contact){
			i++;
		}
	}

	return i;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------ActiveMusicDefinition
function WwiseMms_StrategyMusicDefinition ActiveMusicDefinition(){
	return myBoss.activeMusicDefinition;	
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------HQCam
function XComHeadquartersCamera HQCam(){	
	return XComHeadquartersCamera(XComHeadquartersGame(class'Engine'.static.GetCurrentWorldInfo().Game).PlayerController.PlayerCamera);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------GetHeadquarters
function XComGameState_HeadquartersXCom GetHeadquarters(){
	return XComGameState_HeadquartersXCom(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------OnRoomChangeDetected
function OnRoomChangeDetected(name newRoom){//abstract
}



//------------------------------------------------------------------------------------------------------------------------------------------------------------LogNamesAndIndicies
function LogRoomNamesAndIndicies(){

	local int mapIndex;

	for(mapIndex = 0; mapIndex <= 18;mapIndex++){
		`log("Wwise Mms room index" @mapIndex @"is" @GetHeadquarters().GetRoom(MapIndex).GetFacility().GetMyTemplateName());
	}
}

defaultproperties
{
	currentMapIndex = -1;
}