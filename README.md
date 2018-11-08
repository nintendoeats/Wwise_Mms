# Wwise Mms
A framework which enables Wwise-based interactive music for XCOM 2

_________________________________________ INTRODUCTION  _____________________________________________

*** Description ***

  Wwise Mms is an XCOM 2 mod designed to be installed on top of the existing Music Modding System (MMS) mod developed by the prolific modder Robojumper. It provides hooks which allow modders to create interactive music using the 2014 version of Audiokinetic's Wwise authoring tools. No additional coding is required by modders; they can hook their Wwise sound banks into XCOM 2 using nothing but config files. Wwise supports both it's own music packs and those created for MMS. It is also able to mix the two in a single play session.

  Wwise was originally conceived and built to allow the creation of a music pack based on the soundtrack to System Shock. To my knowledge this is the first time that a true dynamic music system has been ported from one game to another.

*** Wwise Mms vs. MMS ***

  Audio modding for XCOM 2 normally involves creating sound file and "sound cue" objects within the Unreal Development Kit (UDK) for use with Unreal Engine 3's (UE3) base audio system. This system is over a decade old and is fairly limited in what in can do. Here are a few of tits restrictions:
  
  - It only supports uncompressed LPCM audio, making file sizes quite large.
  - The visual programming system does not allow looping logic. It can be pushed beyond its intended limits, but there are many complex behaviours which cannot be performed without custom scripting.
  - In music it is often important to time audio behaviour down to a few milliseconds. Events in a sound cue can have a timing variance of nearly a second.
  
  Most professional UE3 developers use a middleware audio engine such as WWise in order to bypass these issues. Firaxis is no exception. This means that Modders are working with a restricted toolset. While it would be possible to write code hooks to enable some more complex music behaviour in XCOM 2, it is not realistic to attempt to replicate the functionality of WWise using unrealscript. It also faces certain fundemental problems, such as playing through cutscenes because XCOM 2 doesn't know to shut down the stock audio system while playing videos.
  
  MMS uses the sound cue system, and as such it only performs basic music behaviour, finding and playing a new track after certain events (i.e. transitioning from search mode to combat in the tactical section). Wwise Mms allows modders to alter the nature of music based on various in-game events and states, such as a soldier dying or the Avenger travelling across the map screen. This gives modders a huge amount of control while also providing the needed timing precision, down to the indivdual audio sample in some cases.
  
*** Limitations ***

  While the unrealscript side of Wwise Mms is compatible with XCOM 2's War of the Chosen (WOTC), there is a Wwise-side problem which has thusfar prevented new soundbanks from being played in the expansion. This effectively makes Wwise Mms incompatible with WOTC for the time being.

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
  
*** Music Selection ***
 
  Each sound managing class reads two lists of music definitions from the configs. One is a set of tracks to play from the MMS packs, the other is a set of 
