//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_UISL_UIShell.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles a music track with fade-in / fade-out using an AudioComponent
//
//	FILE:		Wwise_Mms_UISL_UIShell.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	General implenting class for Wwise Mms on Main Menu.
//				Removes fade-in from MMS cues.
//				Allows adding of dynamic music changes base on menu.
//---------------------------------------------------------------------------------------

//	Private variables which serve the same purpose as those in MMS are indicated by a "w" prefix.
//	Functions which replace functions from MMS are indicated by a "WwiseMms_" Prefix.
//	The list of Wwise Mms music definitions is called WiserMusicDefs to distinguish them from MMS definitions in configs.

class Wwise_Mms_UISL_UIShell extends MMS_UISL_UIShell config(ShellSound) config(WiseSound) dependson(Wwise_Mms_XComStrategySoundManager) dependson(Wwise_Mms_XComTacticalSoundManager) dependson(Wwise_Mms_AkEventPlayer);

var config array<WwiseMms_ShellMusicDefinition> WiserShellCues;
var array<name> FallbackIDs; //Replaces MMS "FallbackCues" for the sake of naming consistency for each manager. Builds patially from +FallbackCues in configs.
var array<WwiseMms_ShellMusicDefinition> CompleteWwiseMmsShellCuesList;
var WwiseMms_ShellMusicDefinition DefToPlay;
var string eventPlayerPath;
var string modifyingScreenPath;  //These weak references are required to avoid garbage collector issues during loading

var string soundManagerMessengerName;


//-------------------------------------------------------------------------------------------------------Event - OnInit(UIScreen)
//	Called when a new UIScreen is created.
//	Executes the appropriate music behaviour if the new screen is the main menu, multiplayer menu, 
//		or sub-menu of the main menu.
//---------------------------------------------------------------------------------------------
event OnInit(UIScreen Screen){

	local XComShell ShellMenu;
	local WorldInfo WI;
	local Wwise_Mms_Strategy_TrackPlayer cuePlayer;

	WI = class'Helpers'.static.GetWorldInfo();
	

	if (UIFinalShell(Screen) != none || UIMPShell_Base(Screen) != none){
		//Find and stop the Main Menu AKEvent
		ShellMenu = XComShell(WI.Game); 
		ShellMenu.StopMenuMusic(); 

		//	Build and shuffle list of Shell Cues
		CompleteWwiseMmsShellCuesList = WwiseMms_Shuffle(CompileFullShellMusicDefinitionList()); 
		
		//	If the user has not turned on the "allow fallback" setting, the list is sorted so that
		//		the default music is moved to the bottom and will be played only if there is no other music.
		if (!class'MMS_UISL_MCM'.default.bAllowFallback){
			CompleteWwiseMmsShellCuesList.Sort(WwiseMms_SortDefs);
		}
		
		//	Selects the definition on the top of the cue list. Since that list has been shuffled, 
		//		this is a random selection.
		DefToPlay = CompleteWwiseMmsShellCuesList[0];

		//	If the selected definition has a Start_EventPath then it is treated as a Wwise Mms definition
		//		and is send to an event player to be started.
		if(DefToPlay.Start_EventPath != ""){
			ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.Start_EventPath);						`log("Wwise Mms attempts to play" @ defToPlay.MusicID @ "at shell menu");

		//	If the selected definition has a Start_EventPath then it is treated as a standard MMS definition
		//		and is sent to a cue player to be started.	
		}else{
			cuePlayer = ShellMenu.Spawn(class'Wwise_Mms_Strategy_TrackPlayer', ShellMenu);										`log("Wwise Mms attempts to play" @ defToPlay.MusicID @ "at shell menu");
			cuePlayer.WwiseMms_Shell_InitStrategyPlayer(DefToPlay);
			cuePlayer.Play();
		}

		return;
	}

	// Detects and execute events for main menu "options" screen.
	if (DefToPlay.Options_EventPath != "" && UIOptionsPCSCreen(Screen) != none){  
		modifyingScreenPath = PathName(Screen);  
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.Options_EventPath);						`log("Attempting to play options menu event.");
		return;
	}

	// Detects and execute events for "new game" screen.
	if (DefToPlay.NewGame_EventPath != "" && UIShellDifficulty(Screen) != none){  
		modifyingScreenPath = PathName(Screen);  
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.NewGame_EventPath);						`log("Attempting to play new game menu event.");
		return;
	}

	// Detects and execute events for  main menu "load game" screen.
	if (DefToPlay.LoadGame_EventPath != "" && UILoadGame(Screen) != none){  
		modifyingScreenPath = PathName(Screen);  
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.LoadGame_EventPath);						`log("Attempting to play load game menu event.");
		return;
	}																					
}

//-------------------------------------------------------------------------------------------------------Event - OnRemoved(UIScreen)
//	Called when a UIScreen is destroyed.
//	Calls the definition's main menu event if that screen had triggered a modifying Wwise event.
//---------------------------------------------------------------------------------------------
event OnRemoved(UIScreen Screen){

	if(PathName(Screen) == modifyingScreenPath && DefToPlay.Shell_EventPath != ""){
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Shell_EventPath);
		modifyingScreenPath = "";
	}
}


//-------------------------------------------------------------------------------------------------------CompileFullShellMusicDefinitionList
//	Collects MMS definitions, converts them to Wwise Mms definitions and returns a list of
//		all shell music definitions.
//---------------------------------------------------------------------------------------------
function array<WwiseMms_ShellMusicDefinition> CompileFullShellMusicDefinitionList(){

	local array<WwiseMms_ShellMusicDefinition> newListOfDefs;
	local WwiseMms_ShellMusicDefinition newDef;
	local WwiseMms_ShellMusicDefinition iDef;
	local string cue;
	local MusicDefinition Def;
	local MusicDefinition EmptyDef;

	//	 This is the original MMS system for giving shell music definitions names.
	if (!bTransferred){ 
		globalCounter = 0;
		bTransferred = true;
		
		//	These are the entries from music packs designed for MMS.
		foreach ShellCues(cue){
			Def = EmptyDef;
			Def.MusicID = name("Shell_Autogenerated_" $ cue $ "_" $ globalCounter++);
			Def.CuePath = cue;
			MusicDefs.AddItem(Def);
		}
		
		//	These are the entries for the "fallback tracks", copies of the base game music which
		//		are included with MMS.
		foreach FallbackCues(cue){
			Def = EmptyDef;
			Def.MusicID = name("Shell_Autogenerated_" $ cue $ "_" $ globalCounter++);
			Def.CuePath = cue;
			MusicDefs.AddItem(Def);
			
			//	Double-checks that the list of fallback trackj
			if(FallbackIDs.Find(Def.MusicID) == INDEX_NONE){
				FallbackIDs.AddItem(Def.MusicID);
			}
		}
	}

	//	This system gives a name to any Wwise Mms definition which does not already have one.
	foreach WiserShellCues(iDef){
		//Autoname Wiser Shell Cues
		if(iDef.MusicID == name("")){
			iDef.MusicID = name("Shell_Autogenerated_" $ globalCounter++);
		}
	}
	
	//	Start with the existing list of Wwise Mms Shell Cues
	newListOfDefs = WiserShellCues;
	
	//	Convert all of the MMS definitions which we just named and extracted to Wwise Mms definitions.
	//	Add them to the final list.
	if(MusicDefs.Length > 0){ 
		foreach MusicDefs(Def){
			newDef = ConvertStandardDefinitionToWwiseMmsShellMusicDefinition(Def);
			newListOfDefs.AddItem(newDef);
		}
	}
	
	//	Log the definitions for debug purposes.
																																`log("----------Printing Shell Definition List----------");
	foreach newListOfDefs(iDef){
																																`log(iDef.MusicID);
	}
																																`log("----------Finished Shell Definition List----------");
																																
	return newListOfDefs;
}

//-------------------------------------------------------------------------------------------------------ConvertStandardDefinitionToWwiseMmsShellMusicDefinition
//	Returns a Wwise Mms definition with variables taken from an MMS definition.
//---------------------------------------------------------------------------------------------
function WwiseMms_ShellMusicDefinition ConvertStandardDefinitionToWwiseMmsShellMusicDefinition(MusicDefinition oldDef){

	local WwiseMms_ShellMusicDefinition newDef;

	newDef.MusicID = Name("WwiseMms_ConvertedShellDefinition" $ GlobalCounter++);
	newDef.StartCuePath = oldDef.CuePath;

	if (FallbackIDs.Find(oldDef.MusicID) != INDEX_NONE	 &&		FallbackIDs.Find(newDef.MusicID) == INDEX_NONE){
		FallbackIDs.AddItem(newDef.MusicID);
	}

	return(NewDef);
}

//-------------------------------------------------------------------------------------------------------WwiseMms_Shuffle
//	Returns a shuffled copy of an array of WwiseMms_ShellMusicDefinitions.
//---------------------------------------------------------------------------------------------
function array<WwiseMms_ShellMusicDefinition> WwiseMms_Shuffle(array<WwiseMms_ShellMusicDefinition> listOfDefs){

	local int m, i;
	local WwiseMms_ShellMusicDefinition t;

	m = listOfDefs.Length;

	while (m > 0){
		i = Rand(m);
		m--;
		t = listOfDefs[m];
		listOfDefs[m] = listOfDefs[i];
		listOfDefs[i] = t;
	}

	return listOfDefs;
}

//-------------------------------------------------------------------------------------------------------WwiseMms_SortDefs
//	Returns a copy of an array of WwiseMms_ShellMusicDefinitions with entries for base game music
//		shifted to the bottom.
//---------------------------------------------------------------------------------------------
function int WwiseMms_SortDefs(WwiseMms_ShellMusicDefinition A, WwiseMms_ShellMusicDefinition B){

	local bool AIsFallback, BIsFallback;

	AIsFallback = FallbackIDs.Find(A.MusicID) != INDEX_NONE;
	BIsFallback = FallbackIDs.Find(B.MusicID) != INDEX_NONE;

	if (AIsFallback && !BIsFallback){
		return -1;
	}

	return 0;
}

//-------------------------------------------------------------------------------------------------------ConvertMMSSoundGroupToWwiseMmsSoundGroup
//	Returns the Wwise Mms version of a sound group enum used by MMS to identify what part of the
//		game a music definition is for.
//---------------------------------------------------------------------------------------------
function WwiseMms_EStrategySoundGroup ConvertMMSSoundGroupToWwiseMmsSoundGroup(EStrategySoundGroup oldGroup){

	if(oldGroup == eSSG_Chapter01){return weSSG_Chapter01;}
	if(oldGroup == eSSG_Chapter02){return weSSG_Chapter02;}
	if(oldGroup == eSSG_Chapter03){return weSSG_Chapter03;}
	if(oldGroup == eSSG_Geoscape){return weSSG_Geoscape;}
	if(oldGroup == eSSG_GeoDoomClock){return weSSG_GeoDoomClock;}
	if(oldGroup == eSSG_SquadSelect){return weSSG_SquadSelect;}
	if(oldGroup == eSSG_Credits){return weSSG_Credits;}
	if(oldGroup == eSSG_Loss){return weSSG_Loss;}
	if(oldGroup == eSSG_AfterActionFlawless){return weSSG_AfterActionFlawless;}
	if(oldGroup == eSSG_AfterActionCasualties){return weSSG_AfterActionCasualties;}

	return weSSG_AfterActionLoss;
}

//-------------------------------------------------------------------------------------------------------ObtainEventPlayer
//	Finds and returns the object responsible for playing AkEvents, creating it if it does not exist.
//---------------------------------------------------------------------------------------------
function Wwise_Mms_AkEventPlayer ObtainEventPlayer(){

	local XComShell ShellMenu;
	local WorldInfo WI;
	local Wwise_Mms_AkEventPlayer playerSeek;

	//	Looks for a pre-existing player and returns it if it exists.
	playerSeek = Wwise_Mms_AkEventPlayer(class 'Object'.static.FindObject(eventPlayerPath, class 'Wwise_Mms_AkEventPlayer'));

	if (playerSeek != None){
		return playerSeek;
	}

	WI = class'Helpers'.static.GetWorldInfo();
	ShellMenu = XComShell(WI.Game); 

	playerSeek = ShellMenu.Spawn(class'Wwise_Mms_AkEventPlayer', ShellMenu);														`log("Wwise Mms finds no event player! Creating...");

	//	Stores the path to new player so that it will be found next time.
	eventPlayerPath = PathName(playerSeek);

	return playerSeek;
}


//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS

function int SortDefs(MusicDefinition A, MusicDefinition B){}																		`log("MMS SortDefs intercepted.");}
function Shuffle(){																													`log("MMS Shuffle intercepted.");}
