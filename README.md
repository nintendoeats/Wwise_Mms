# Wwise Mms
A framework which enables Wwise-based interactive music for XCOM 2

_________________________________________ INTRODUCTION  _____________________________________________

*** Description ***

  Wwise Mms is an XCOM 2 mod designed to be installed on top of the existing Music Modding System (MMS) mod developed by the prolific modder Robojumper. It provides hooks which allow modders to create interactive music using the 2014 version of Audiokinetic's Wwise authoring tools. No additional coding is required by modders; they can hook their Wwise sound banks into XCOM 2 using nothing but config files. Wwise supports both it's own music packs and those created for MMS. It is also able to mix the two in a single play session.

  Wwise was originally conceived and built to allow the creation of a music pack based on the soundtrack to System Shock. To my knowledge this is the first time that a true dynamic music system has been ported from one game to another.


*** Limitations ***

  While the unrealscript side of Wwise Mms is compatible with XCOM 2's War of the Chosen expansion, there is a Wwise-side problem which has thusfar prevented new soundbanks from being played. This effectively makes Wwise Mms incompatible with the expansion.

  Because of the way XCOM 2 loads in assets, it is nessecary to place either the sound bank files or hard links to them in one of the game's content folders. Simply subscribing to the mod in Steam Workshop is not enough. This can typically be achieved using a .bat file.
  
  
 *** Instructions for Modders ***
 
  An extensive guide for creating Wwise Mms music packs can be found here: https://steamcommunity.com/sharedfiles/filedetails/?id=1401366221
  
  The remainder of this document regards the unrealscript which underlies Wwise Mms. It assumes that the reader is familiar with XCOM 2 and has a basic understanding of XCOM 2 modding and unrealscript.
    
_________________________________________ CODE STRUCTURE  _________________________________________
 
*** Overriding Music Modding System ***

  Because MMS music packs are stored in config files, Wwise Mms needs classes which have names mirroring those of MMS. Simply using those names would create conflicts if end-users installed both systems, so instead Wwise Mms inherits from and overrides the MMS classes. Prior to the development of Wwise Mms the XCOM 2 modding community believed that mod classes could not be overriden. In fact, doing so simply requires manually replacing the MMS entries in Engine.ModClassOverides with ones that connect to the Wwise Mms classes. This is done in X2DownloadableContentInfo_Wwise_Mms.OnPostTemplatesCreated() .
  
   Because the MMS UIScreen listeners cannot be disabled, the functions they call are overridden with empty functions so that they cannot initiate any behaviour.
   
   
*** Sound Managing Classes ***

  XCOM 2 features two "SoundManager" classes which Wwise Mms overrides. One is for the game's strategy mode, the other is for the tactical mode. Overriding these and the appropriate functions prevents all of the original music from playing. In the case of tactical, some ambient noises need to be renabled.
  
  The main screen music is played by the class Wwise_Mms_UISL_UIShell . This is a UIscreen listener which automatically starts playing music when the main menu is detected.
  
  The music played in the skyranger on the way to a mission is handled by Wwise_Mms_UISL_UIDropShipBriefing_MissionStart . 
  
  The music played in the skyranger on the way back to base is handled by Wwise_Mms_XComTacticalSoundManager .
  
  The music played on the landing pad after return to base is handled by Wwise_Mms_XComStrategySoundManager . There is a short silence between Skyranger and landing pad as the audio engine resets. This is masked by rocket sounds from the Skyranger.
