//---------------------------------------------------------------------------------------
//  FILE:   X2DownloadableContentInfo_Wwise_Mms.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_Wwise_Mms extends X2DownloadableContentInfo;

//----------------------------------------------------------------------------------------------------------------------------ReplaceOverrideEntry
static function ReplaceOverrideEntry(string baseClass, string oldOverride, string newOverride){

	local ModClassOverrideEntry entryKill;
	local ModClassOverrideEntry entryAdd;

	entryKill.BaseGameClass= name(baseClass);
	entryKill.ModClass= name(oldOverride);

	entryAdd.BaseGameClass= name(baseClass);
	entryAdd.ModClass= name(newOverride);

	class'Engine'.static.GetEngine().ModClassOverrides.RemoveItem(entryKill);
	class'Engine'.static.GetEngine().ModClassOverrides.AddItem(entryAdd);

}

//----------------------------------------------------------------------------------------------------------------------------PrintEnemyTemplateNames
static function PrintEnemyTemplateNames(){

    local X2CharacterTemplateManager CharacterTemplateManager;
    local X2DataTemplate CharacterTemplate;
    local array<name> CharacterTemplateStack;
    
    CharacterTemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
    
	`log("-----Wwise Mms printing full enemy listing-----");

    foreach CharacterTemplateManager.IterateTemplates(CharacterTemplate, none){
        if (CharacterTemplateStack.Find(X2CharacterTemplate(CharacterTemplate).DataName) == INDEX_NONE){
            if(X2CharacterTemplate(CharacterTemplate) != none){
                CharacterTemplateStack.AddItem(X2CharacterTemplate(CharacterTemplate).DataName);
                `LOG(X2CharacterTemplate(CharacterTemplate).DataName @ X2CharacterTemplate(CharacterTemplate).CharacterGroupName,, 'CharacterTemplate');
            }
        }
    }

	`log("-----Wwise Mms finished printing full enemy listing-----");
}

//----------------------------------------------------------------------------------------------------------------------------LogPrintFullOverrideList
static function LogPrintFullOverrideList(){

	local ModClassOverrideEntry TempEntry;

	`log("--------------------Wwise Mms Printing Override List!--------------------");
	foreach class'Engine'.static.GetEngine().ModClassOverrides(TempEntry){	`log(TempEntry.BaseGameClass $" -> " $ TempEntry.ModClass);}
	`log("--------------------Finished Printing Override List!---------------------");
}








/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated(){
	
	ReplaceOverrideEntry("XComStrategySoundManager","MMS_XComStrategySoundManager","Wwise_Mms.Wwise_Mms_XComStrategySoundManager");
	ReplaceOverrideEntry("XComTacticalSoundManager","MMS_XComTacticalSoundManager","Wwise_Mms.Wwise_Mms_XComTacticalSoundManager");
	LogPrintFullOverrideList();

	//These lines disable the MMS screen listeners completely.
	MMS_UISL_UIDropShipBriefing_MissionStart(`CONTENT.RequestGameArchetype("MusicModdingSystem.Default__MMS_UISL_UIDropShipBriefing_MissionStart")).ScreenClass = class 'UISecondWave';
	MMS_UISL_UIShell(`CONTENT.RequestGameArchetype("MusicModdingSystem.Default__MMS_UISL_UIShell")).ScreenClass = class 'UISecondWave';


	//PrintEnemyTemplateNames();
}












/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame(){}

/// <summary>
/// This method is run when the player loads a saved game directly into Strategy while this DLC is installed
/// </summary>
static event OnLoadedSavedGameToStrategy(){}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed. When a new campaign is started the initial state of the world
/// is contained in a strategy start state. Never add additional history frames inside of InstallNewCampaign, add new state objects to the start state
/// or directly modify start state objects
/// </summary>
static event InstallNewCampaign(XComGameState StartState){}

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// Allows dlcs/mods to modify the start state before launching into the mission
/// </summary>
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState){}

/// <summary>
/// Called when the player completes a mission while this DLC / Mod is installed.
/// </summary>
static event OnPostMission(){}

/// <summary>
/// Called when the player is doing a direct tactical->tactical mission transfer. Allows mods to modify the
/// start state of the new transfer mission if needed
/// </summary>
static event ModifyTacticalTransferStartState(XComGameState TransferStartState){}

/// <summary>
/// Called after the player exits the post-mission sequence while this DLC / Mod is installed.
/// </summary>
static event OnExitPostMissionSequence(){}

/// <summary>
/// Called when the difficulty changes and this DLC is active
/// </summary>
static event OnDifficultyChanged(){}

simulated function EnableDLCContentPopupCallback(eUIAction eAction){}

/// <summary>
/// Called when viewing mission blades with the Shadow Chamber panel, used primarily to modify tactical tags for spawning
/// Returns true when the mission's spawning info needs to be updated
/// </summary>
static function bool UpdateShadowChamberMissionInfo(StateObjectReference MissionRef){	return false;}

/// <summary>
/// Called from X2AbilityTag:ExpandHandler after processing the base game tags. Return true (and fill OutString correctly)
/// to indicate the tag has been expanded properly and no further processing is needed.
/// </summary>
static function bool AbilityTagExpandHandler(string InString, out string OutString){	return false;}

/// <summary>
/// Called from XComGameState_Unit:GatherUnitAbilitiesForInit after the game has built what it believes is the full list of
/// abilities for the unit based on character, class, equipment, et cetera. You can add or remove abilities in SetupData.
/// </summary>
static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay){}

