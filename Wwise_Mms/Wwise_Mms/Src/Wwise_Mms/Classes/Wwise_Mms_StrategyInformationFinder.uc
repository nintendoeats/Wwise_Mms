//---------------------------------------------------------------------------------------
//  FILE:    Wwise_Mms_StrategyInformationFinder.uc
//  AUTHOR:  Adrian Hall --  2018
//  PURPOSE: Contains functions for finding and analyzing information about the game
//				state in strategy mode.
//			 Extended by Wwise_Mms_StrategyBuddy in an attempt to replicate partial 
//				class functionality within Unrealscript.
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

//-------------------------------------------------------------------------------------------------------DoRoomCheck
//	Finds out what room the camera is focussed on.
//	If the room has changed, cycles the room adjacency arrays and calls OnRoomChangeDetected().
//---------------------------------------------------------------------------------------------
function DoRoomCheck(){

	local name roomType;
	local array<name> newAdjacencyArray;

	//	Return if the room has not changed.
	if(HQCam().CurrentRoom == currentRoom){
		return;
	}

	previousRoom = currentRoom;
	currentRoom = HQCam().CurrentRoom;

	roomType = GetRoomTypeFromLocationName(currentRoom, currentMapIndex);

	previousAdjacentRooms = adjacentRooms;

	//	currentMapIndex will be -1 if the camera is not looking at a room.
	//	In that instance, there are no adjacent rooms and the array should remain empty.
	if(currentMapIndex != -1){
		newAdjacencyArray = GetAdjacentRoomTypes(currentMapIndex);
	}

	adjacentRooms = newAdjacencyArray;
	
	OnRoomChangeDetected(GetRoomTypeFromLocationName(roomType));

}

//-------------------------------------------------------------------------------------------------------CheckScanning
//	Returns whether or not The Avenger is scanning in the geoscape.
//---------------------------------------------------------------------------------------------
function bool CheckScanning(){
	
	return XComHeadquartersGame(class'Engine'.static.GetCurrentWorldInfo().Game).GetGamecore().GetGeoscape().IsScanning();
}

//-------------------------------------------------------------------------------------------------------CheckFinishedScanning
//	Returns whether or not The Avenger's last scan site was completed.
//---------------------------------------------------------------------------------------------
function bool CheckFinishedScanning(){

	if(lastScanSite == none){
		return false;
	}
	 return lastScanSite.IsScanComplete();
}

//-------------------------------------------------------------------------------------------------------CheckFlying
//	Returns whether or not The Avenger is flying in the geoscape.
//---------------------------------------------------------------------------------------------
function bool CheckFlying(){

	local XComGameState_HeadquartersXCom theAvenger;
	
	theAvenger = GetHeadquarters();

	if(theAvenger.LiftingOff || theAvenger.Flying){ //Counting the landing state as landed is better for music transitions
		return true;
	}

	return false;
}

//-------------------------------------------------------------------------------------------------------CheckDoomLevel
//	Returns the current level of Doom.
//---------------------------------------------------------------------------------------------
function int CheckDoomLevel(){

	return class'UIUtilities_Strategy'.static.GetAlienHQ().GetCurrentDoom();
}

//-------------------------------------------------------------------------------------------------------CheckDeadSoldierCount
//	Returns the number of soldiers who have died in this campaign.
//---------------------------------------------------------------------------------------------
function int CheckDeadSoldierCount(){

	return class'UIUtilities_Strategy'.static.GetXComHQ().DeadCrew.Length;
}

//-------------------------------------------------------------------------------------------------------CheckFacilityCount
//	Returns the number of Avenger facilities built in rooms by the player.
//	This count does not include the built-in facilities (i.e. Engineering, Memorial).
//---------------------------------------------------------------------------------------------
function int CheckFacilityCount(){

	local int count;

	count = class'UIUtilities_Strategy'.static.GetXComHQ().Facilities.Length;
	
	//	Subtract the built-in facilities present at campaign start.
	count -= 7;	

	return count;
}

//-------------------------------------------------------------------------------------------------------GetAdjacentRoomTypes
//	Returns an array containing the template names of room types which are adjacent to the
//		room currently being viewed.
//	This array may contain duplicate names if there is more than one of a room type detected.
//---------------------------------------------------------------------------------------------
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

																													`log("Wwise mms found" @arrayToReturn.Length @"adjacent rooms.");

	return arrayToReturn;
}


//-------------------------------------------------------------------------------------------------------GetRoomTypeFromLocationName
//	Takes a room template name and returns a human-friendly room type name.
//	The returned name is the one that should be used by music pack designers.
//	If the room is a grid room, the out paramater is its index on the map.
//	Any room that is not a grid room will return a mapIndex of -1 instead of its actual index.
//	See ConvertGridLocationToMapIndex() for description of map indexes.
//---------------------------------------------------------------------------------------------
function name GetRoomTypeFromLocationName(name roomName, optional out int mapIndex){

	//	The makeup of room template names is somewhat haphazard.
	//	This function uses known formats for these names and is not robust against new ones.
	//	Known cues are used to determine where in nameBreakdown the useful facility name is.
	//	Research, Hangar and Engineering are hard-coded names added for clarity.
	
	local int row;
	local int column;
	local array<string> nameBreakdown;
	local name nameToReturn;

																													`log("Wwise Mms parsing room location" @roomName);

	nameBreakdown = SplitString(string(roomName),"_",true);

	mapIndex = -1;
	nameToReturn = roomName;

	//	"AddonCam" means a grid room.
	if(nameBreakdown[0] == "AddonCam"){ 
		row = int(Right(nameBreakdown[1],1));
		column = int(Right(nameBreakdown[2],1));
		mapIndex = ConvertGridLocationToMapIndex(row,column);
																													`log("Wwise mms room found map index" @mapindex @"From grid reference" @row @"," @column);
		nameToReturn = GetHeadquarters().GetRoom(mapIndex).GetFacility().GetMyTemplateName();
	}

	//	This is a built-in room.
	if(nameBreakdown[0] == "UIDisplayCam"){ 
		nameToReturn = name(nameBreakdown[1]);
	}
	
	//	This is also a built-in room.
	if(nameBreakdown[0] == "UIBlueprint"){
		nameToReturn = name(nameBreakdown[1]);
	}

	//	This is usually squad select.
	if(nameBreakdown[1] == "UIDisplayCam"){
		nameToReturn = name(nameBreakdown[2]);
	}

	if(nameToReturn == 'PowerCore'){
		nametoReturn = 'Research';
	}

	//	Engineering contains two cameras.
	if(nameToReturn == 'Storage'|| nameToReturn == 'BuildItems'){
		nametoReturn = 'Engineering';
	}

	//	All of the fixed facilities on the right side of the ship are currently presented as "Hangar".
	if(nameToReturn == 'Armory' || nameToReturn == 'ArmoryMenu' || nameToReturn == 'Promotion' || nameToReturn == 'Loadout' || nameToReturn == 'CustomizeMenu' || nameToReturn == 'PromotionInjured'){
		nametoReturn = 'Hangar';
	}

	return nameToReturn;
}

//-------------------------------------------------------------------------------------------------------ConvertGridLocationToMapIndex
//	Returns the mapIndex for a location in the room grid.
//	The mapIndex is required to find the room in that location.
//---------------------------------------------------------------------------------------------
function int ConvertGridLocationToMapIndex(int row, int column){

	//	XCOM 2 gives rooms names for use by the camera.
	//	These names are based on the grid rather than that room's stored location on the map.
	//	Once we have extracted the grid coordinates, this function simply undoes the math.
	//	The mapIndices are counted starting from 0 at the top left, reading left to right 
	//		and then top to bottom.
	
	local int mapIndex;

	mapIndex = (row * 3);	//Start with the base zero row
	mapIndex += column - 1;		//Add the base zero column

	return mapIndex;

	//	This is the base game code that we are undoing above.
	//if (RoomStateObject.MapIndex >= 3 && RoomStateObject.MapIndex <= 14){
		//GridIndex = RoomStateObject.MapIndex - 3;
		//RoomRow = (GridIndex / 3) + 1;
		//RoomColumn = (GridIndex % 3) + 1;
		//CameraName = "AddonCam" $ "_R" $ RoomRow $ "_C" $ RoomColumn;
	//}
}

//-------------------------------------------------------------------------------------------------------CheckContactedRegionCount
//	Returns the number of regions that have been contacted so far in this campaign.
//---------------------------------------------------------------------------------------------
function int CheckContactedRegionCount(){

	local XComGameStateHistory History;
	local XComGameState_WorldRegion RegionState;
	local int i;

	i = 0;

	History = class'XComGameStateHistory'.static.GetGameStateHistory();

	//	Iterates through each region and adds 1 to the count if that region has a
	//		resistance level higher than the "contacted" enum's value.
	foreach History.IterateByClassType(class'XComGameState_WorldRegion', RegionState){
		if(RegionState.ResistanceLevel >= eResLevel_Contact){
			i++;
		}
	}

	return i;
}

//-------------------------------------------------------------------------------------------------------ActiveMusicDefinition
//	Returns the active music definition according to the strategy sound manager.
//---------------------------------------------------------------------------------------------
function WwiseMms_StrategyMusicDefinition ActiveMusicDefinition(){

	return myBoss.activeMusicDefinition;	
}

//-------------------------------------------------------------------------------------------------------HQCam
//	Returns the current camera.
//---------------------------------------------------------------------------------------------
function XComHeadquartersCamera HQCam(){
	
	return XComHeadquartersCamera(XComHeadquartersGame(class'Engine'.static.GetCurrentWorldInfo().Game).PlayerController.PlayerCamera);
}

//-------------------------------------------------------------------------------------------------------GetHeadquarters
//	Returns the XComGameState_HeadquartersXCom object.
//---------------------------------------------------------------------------------------------
function XComGameState_HeadquartersXCom GetHeadquarters(){

	return XComGameState_HeadquartersXCom(class'XComGameStateHistory'.static.GetGameStateHistory().GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
}

//-------------------------------------------------------------------------------------------------------OnRoomChangeDetected
//	Called by DoRoomCheck if the currently viewed room name has changed.
//	This is intended as an abstract class for use by children.
//---------------------------------------------------------------------------------------------
function OnRoomChangeDetected(name newRoom){
	//	abstract
}


//-------------------------------------------------------------------------------------------------------LogRoomNamesAndIndicies
//	DEBUG: Finds the names and indices of all currently existing room templates and prints 
//		them to the log.
//---------------------------------------------------------------------------------------------
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