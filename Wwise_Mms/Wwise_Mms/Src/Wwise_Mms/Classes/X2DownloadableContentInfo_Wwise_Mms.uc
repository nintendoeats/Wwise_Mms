//---------------------------------------------------------------------------------------
//  FILE:  		X2DownloadableContentInfo_Wwise_Mms.uc                                    
//	CREATED:	Adrian Hall -- 2018
//	PURPOSE:	Overrides the MMS class functions and disables the MMS UIShell listeners.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_Wwise_Mms extends X2DownloadableContentInfo;

//-------------------------------------------------------------------------------------------------------OnPostTemplatesCreated
// Firaxis: Called after the Templates have been created (but before they are validated) while 
// this DLC / Mod is installed.
//---------------------------------------------------------------------------------------------
static event OnPostTemplatesCreated(){
	
	//This is the earliest place where we can remove the MMS override entries and replace them with our own.
	//This must be done manually, XCOM 2 does not support mods overriding other mods.
	//The override list is printed as a debug measure, in case the replacement doesn't work.
	ReplaceOverrideEntry("XComStrategySoundManager","MMS_XComStrategySoundManager","Wwise_Mms.Wwise_Mms_XComStrategySoundManager");
	ReplaceOverrideEntry("XComTacticalSoundManager","MMS_XComTacticalSoundManager","Wwise_Mms.Wwise_Mms_XComTacticalSoundManager");
	LogPrintFullOverrideList();

	//These lines disable the MMS screen listeners completely by changing the screen they listen for to something that is unused.
	MMS_UISL_UIDropShipBriefing_MissionStart(`CONTENT.RequestGameArchetype("MusicModdingSystem.Default__MMS_UISL_UIDropShipBriefing_MissionStart")).ScreenClass = class 'UISecondWave';
	MMS_UISL_UIShell(`CONTENT.RequestGameArchetype("MusicModdingSystem.Default__MMS_UISL_UIShell")).ScreenClass = class 'UISecondWave';
}


//-------------------------------------------------------------------------------------------------------ReplaceOverrideEntry
// Removes the existing override entry for baseClass if the overriding class is oldOverride.
// Adds a new override entry for base class.
//---------------------------------------------------------------------------------------------
static function ReplaceOverrideEntry(string baseClass, string oldOverride, string newOverride){

	local ModClassOverrideEntry entryToKill;
	local ModClassOverrideEntry entryToAdd;

	entryToKill.BaseGameClass= name(baseClass);
	entryToKill.ModClass= name(oldOverride);

	entryToAdd.BaseGameClass= name(baseClass);
	entryToAdd.ModClass= name(newOverride);

	class'Engine'.static.GetEngine().ModClassOverrides.RemoveItem(entryToKill);
	class'Engine'.static.GetEngine().ModClassOverrides.AddItem(entryToAdd);

}

//-------------------------------------------------------------------------------------------------------PrintEnemyTemplateNames
// Finds the list of template names for all enemy types and prints them to the log.
//---------------------------------------------------------------------------------------------
static function PrintEnemyTemplateNames(){

    local X2CharacterTemplateManager CharacterTemplateManager;
    local X2DataTemplate CharacterTemplate;
    local array<name> CharacterTemplateStack;
    
    CharacterTemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
    
    `log("-----Wwise Mms printing full enemy listing-----");

    //Loops through all of the templates, printing the DataName of any X2CharacterTemplate found.
    //Maintains a list of names printed so far and does not print repeats.
    foreach CharacterTemplateManager.IterateTemplates(CharacterTemplate, none){
        if (CharacterTemplateStack.Find(X2CharacterTemplate(CharacterTemplate).DataName) == INDEX_NONE){
            if(X2CharacterTemplate(CharacterTemplate) != none){
                CharacterTemplateStack.AddItem(X2CharacterTemplate(CharacterTemplate).DataName);
                `log(X2CharacterTemplate(CharacterTemplate).DataName @ X2CharacterTemplate(CharacterTemplate).CharacterGroupName,, 'CharacterTemplate');
            }
        }
    }

    `log("-----Wwise Mms finished printing full enemy listing-----");
}

//-------------------------------------------------------------------------------------------------------LogPrintFullOverrideList
// Finds the list of all class overrides and prints them to the log.
//---------------------------------------------------------------------------------------------
static function LogPrintFullOverrideList(){

	local ModClassOverrideEntry TempEntry;

	`log("--------------------Wwise Mms Printing Override List!--------------------");
	foreach class'Engine'.static.GetEngine().ModClassOverrides(TempEntry){	`log(TempEntry.BaseGameClass $" -> " $ TempEntry.ModClass);}
	`log("--------------------Finished Printing Override List!---------------------");
}
