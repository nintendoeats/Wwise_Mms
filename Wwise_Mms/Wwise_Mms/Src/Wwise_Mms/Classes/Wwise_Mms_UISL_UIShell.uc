//---------------------------------------------------------------------------------------
//  ORIGINAL:   MMS_UISL_UIShell.uc
//  AUTHOR:		robojumper --  2016
//  PURPOSE:	Handles a music track with fade-in / fade-out using an AudioComponent
//
//	FILE:		Wwise_Mms_UISL_UIShell.uc
//	MODIFIED:	Adrian Hall -- 2018
//	PURPOSE:	Removes fade-in and allows use of music which changes dynamically by menu
//---------------------------------------------------------------------------------------

//Alternate private variables are indicated by a "w" prefix.
//Alternate functions and classes are indicated by a "WwiseMms_" Prefix
//The list of Wwise Mms music definitions is called WiserMusicDefs to make the difference more obvious in configs

class Wwise_Mms_UISL_UIShell extends MMS_UISL_UIShell config(ShellSound) config(WiseSound) dependson(Wwise_Mms_XComStrategySoundManager) dependson(Wwise_Mms_XComTacticalSoundManager) dependson(Wwise_Mms_AkEventPlayer);

var config array<WwiseMms_ShellMusicDefinition> WiserShellCues;
var array<name> FallbackIDs; //Replaces FallbackIDs for the sake of naming consistency for each manager. Builds patially from +FallbackCues in the config.
var array<WwiseMms_ShellMusicDefinition> CompleteWwiseMmsShellCuesList;
var WwiseMms_ShellMusicDefinition DefToPlay;
var string eventPlayerPath;
var string modifyingScreenPath;  //These weak references are required to avoid garbage collector issues during loading

var string soundManagerMessengerName;


//----------------------------------------------------------------------------------------------------------------------------Event - OnInit(UIScreen)
event OnInit(UIScreen Screen){

	local XComShell ShellMenu;
	local WorldInfo WI;
	local Wwise_Mms_Strategy_TrackPlayer cuePlayer;

	WI = class'Helpers'.static.GetWorldInfo();
	

	//Shell Screen Finder
	if (UIFinalShell(Screen) != none || UIMPShell_Base(Screen) != none){
		ShellMenu = XComShell(WI.Game); 
		ShellMenu.StopMenuMusic(); //Find and stop the Main Menu AKEvent

		CompleteWwiseMmsShellCuesList = WwiseMms_Shuffle(CompileFullShellMusicDefinitionList()); //	Build and shuffle list of Shell Cues

		if (!class'MMS_UISL_MCM'.default.bAllowFallback){CompleteWwiseMmsShellCuesList.Sort(WwiseMms_SortDefs); }

		DefToPlay = CompleteWwiseMmsShellCuesList[0];

		if(defToPlay.Start_EventPath != ""){
			ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.Start_EventPath);//"SoundMenuMusic.Play_Main_Menu_Music");//

			`log("Wwise Mms attempts to play" @ defToPlay.MusicID @ "at shell menu");


		}else{
			cuePlayer = ShellMenu.Spawn(class'Wwise_Mms_Strategy_TrackPlayer', ShellMenu);		`log("Wwise Mms attempts to play" @ defToPlay.MusicID @ "at shell menu");
			cuePlayer.WwiseMms_Shell_InitStrategyPlayer(DefToPlay);
			cuePlayer.Play();
		}

		return;
	}

	// Options menu finder
	if (DefToPlay.Options_EventPath != "" && UIOptionsPCSCreen(Screen) != none){  
		modifyingScreenPath = PathName(Screen);  
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.Options_EventPath);						`log("Attempting to play options menu event.");
		return;
	}

	// New game menu finder
	if (DefToPlay.NewGame_EventPath != "" && UIShellDifficulty(Screen) != none){  
		modifyingScreenPath = PathName(Screen);  
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.NewGame_EventPath);						`log("Attempting to play new game menu event.");
		return;
	}

	// Load game menu finder
	if (DefToPlay.LoadGame_EventPath != "" && UILoadGame(Screen) != none){  
		modifyingScreenPath = PathName(Screen);  
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Append $ DefToPlay.LoadGame_EventPath);						`log("Attempting to play load game menu event.");
		return;
	}																					
}

//----------------------------------------------------------------------------------------------------------------------------Event - OnRemoved(UIScreen)
event OnRemoved(UIScreen Screen){					//If this screen had modified our music, play the shell return event.

	if(PathName(Screen) == modifyingScreenPath && DefToPlay.Shell_EventPath != ""){
		ObtainEventPlayer().PlayMusicStartEventFromPath(DefToPlay.Shell_EventPath);
		modifyingScreenPath = "";
	}
}

//----------------------------------------------------------------------------------------------------------------------------SortDefs
function int SortDefs(MusicDefinition A, MusicDefinition B){
}

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_Shuffle
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

//----------------------------------------------------------------------------------------------------------------------------WwiseMms_SortDefs
function int WwiseMms_SortDefs(WwiseMms_ShellMusicDefinition A, WwiseMms_ShellMusicDefinition B){

	local bool AIsFallback, BIsFallback;

	AIsFallback = FallbackIDs.Find(A.MusicID) != INDEX_NONE;
	BIsFallback = FallbackIDs.Find(B.MusicID) != INDEX_NONE;

	if (AIsFallback && !BIsFallback){
		return -1;
	}

	return 0;
}

//----------------------------------------------------------------------------------------------------------------------------CompileFullShellMusicDefinitionList
function array<WwiseMms_ShellMusicDefinition> CompileFullShellMusicDefinitionList(){

	local array<WwiseMms_ShellMusicDefinition> newListOfDefs;
	local WwiseMms_ShellMusicDefinition newDef;
	local WwiseMms_ShellMusicDefinition iDef;
	local string cue;
	local MusicDefinition Def;
	local MusicDefinition EmptyDef;

	if (!bTransferred){ // This is the original system for obtaining cue names
		globalCounter = 0;
		bTransferred = true;

		foreach ShellCues(cue){
			Def = EmptyDef;
			Def.MusicID = name("Shell_Autogenerated_" $ cue $ "_" $ globalCounter++);
			Def.CuePath = cue;
			MusicDefs.AddItem(Def);
		}

		foreach FallbackCues(cue){
			Def = EmptyDef;
			Def.MusicID = name("Shell_Autogenerated_" $ cue $ "_" $ globalCounter++);
			Def.CuePath = cue;
			MusicDefs.AddItem(Def);

			if(FallbackIDs.Find(Def.MusicID) == INDEX_NONE){ //Why not make sure? Not important, may as well.
				FallbackIDs.AddItem(Def.MusicID);
			}
		}
	}


	foreach WiserShellCues(iDef){	//Autoname Wiser Shell Cues
		if(iDef.MusicID == name("")){
			iDef.MusicID = name("Shell_Autogenerated_" $ globalCounter++);
		}
	}

	newListOfDefs = WiserShellCues; //Start with the existing list of Wwise Mms Shell Cues

	if(MusicDefs.Length > 0){ //Add all of the ones that the vanilla system just extracted
		foreach MusicDefs(Def){
			newDef = ConvertStandardDefinitionToWwiseMmsShellMusicDefinition(Def);
			newListOfDefs.AddItem(newDef);
		}
	}

																									`log("----------Printing Shell Definition List----------");
																									foreach newListOfDefs(iDef){`log(iDef.MusicID);}
																									`log("----------Finished Shell Definition List----------");
	return newListOfDefs;
}


//----------------------------------------------------------------------------------------------------------------------------ConvertStandardDefinitionToWwiseMmsShellMusicDefinition
function WwiseMms_ShellMusicDefinition ConvertStandardDefinitionToWwiseMmsShellMusicDefinition(MusicDefinition oldDef){

	local WwiseMms_ShellMusicDefinition newDef;

	newDef.MusicID = Name("WwiseMms_ConvertedShellDefinition" $ GlobalCounter++);
	newDef.StartCuePath = oldDef.CuePath;

	if (FallbackIDs.Find(oldDef.MusicID) != INDEX_NONE	 &&		FallbackIDs.Find(newDef.MusicID) == INDEX_NONE){
		FallbackIDs.AddItem(newDef.MusicID);
	}

	return(NewDef);
}

//----------------------------------------------------------------------------------------------------------------------------ConvertMMSSoundGroupToWwiseMmsSoundGroup
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

//----------------------------------------------------------------------------------------------------------------------------ObtainEventPlayer
function Wwise_Mms_AkEventPlayer ObtainEventPlayer(){

	local XComShell ShellMenu;
	local WorldInfo WI;
	local Wwise_Mms_AkEventPlayer playerSeek;

	playerSeek = Wwise_Mms_AkEventPlayer(class 'Object'.static.FindObject(eventPlayerPath, class 'Wwise_Mms_AkEventPlayer'));

	if (playerSeek != None){return playerSeek;}

	WI = class'Helpers'.static.GetWorldInfo();
	ShellMenu = XComShell(WI.Game); 

	playerSeek = ShellMenu.Spawn(class'Wwise_Mms_AkEventPlayer', ShellMenu);							`log("Wwise Mms finds no event player! Creating...");

	eventPlayerPath = PathName(playerSeek);

	return playerSeek;
}


//----------------------------------------------------------------------------------------------------------------------------MMS FUNCTION INTERCEPTIONS
function Shuffle(){																		`log("MMS Shuffle intercepted.");}