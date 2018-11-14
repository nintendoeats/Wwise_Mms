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

  Because of the way XCOM 2 loads in assets, it is nessecary to place either the sound bank files or hard links to them in one of the game's content folders. This means that simply subscribing to the mod in Steam Workshop is not enough. Supplying the user with a .bat file which creates links is a way to make this as painless as possible for them.
  
  
 *** Instructions for Modders ***
 
  An extensive guide for creating Wwise Mms music packs can be found here: https://steamcommunity.com/sharedfiles/filedetails/?id=1401366221
  
  The remainder of this document regards the unrealscript which underlies Wwise Mms. It assumes that the reader is familiar with XCOM 2 and has a basic understanding of XCOM 2 modding and unrealscript.


    
_________________________________________ OVERALL APPLICATION DESIGN  _________________________________________
 
*** Overriding Music Modding System ***

  Because MMS music packs are stored in config files, Wwise Mms needs classes which have names mirroring those of MMS. Simply using those names would create conflicts if end-users installed both systems, so instead Wwise Mms inherits from and overrides the MMS classes. Prior to the development of Wwise Mms the XCOM 2 modding community believed that mod classes could not be overriden. In fact, doing so simply requires manually replacing the MMS entries in Engine.ModClassOverides with ones that connect to the Wwise Mms classes. This is done in X2DownloadableContentInfo_Wwise_Mms.OnPostTemplatesCreated() .
  
  Because the MMS UIScreen listeners cannot be disabled, the functions they call are overridden with empty functions so that they cannot initiate any behaviour. This strategy is used elsewhere as a precaution. Such functions are labelled "Interceptions".
   
   
*** Sound Managing Classes ***

  XCOM 2 features two "SoundManager" classes which Wwise Mms overrides. One is for the game's strategy mode, the other is for the tactical mode. Overriding these and the appropriate functions prevents all of the original music from playing. In the case of tactical, some ambient noises need to be renabled. Sound Managers are created and destroyed by the base XCOM 2 code, not by Wwise Mms itself.
  
  The main screen music is played by the class Wwise_Mms_UISL_UIShell . This is a UIscreen listener which automatically starts playing music when the main menu is detected.
  
  The music played in the skyranger on the way to a mission is handled by Wwise_Mms_UISL_UIDropShipBriefing_MissionStart . 
  
  The music played in the skyranger on the way back to base is handled by Wwise_Mms_XComTacticalSoundManager .
  
  The music played on the landing pad after return to base is handled by Wwise_Mms_XComStrategySoundManager . There is a short silence between Skyranger and landing pad as the audio engine resets. This is masked by rocket sounds from the Skyranger.


*** Structure of a Music Definition ***

  There are several types of music definition. Specific details can be found in the mod creation guide. The below is a general description of the information stored in a music definition. These definitions are structs stored in the relevent sound managers. Note that while MMS and Wwise Mms definitions are different classes within mods, Wwise Mms converts MMS definitions into Wwise Mms definitions so that they can be stored in a single list.

  -MMS Definitions-

  	A "track" in MMS is the string path to a UE3 "Sound Cue" object within one of the engine's .UPK package files. These cues are linked to "Sound Wave" objects, LPCM audio files which are also stored in .UPK files. These paths are stored alongside other information such as what type of environment a tactical definition may be used for, or what sort of game state they apply to (i.e. squad select screen, geoscape screen, in-combat). Tactical music definitions contain two sound cue paths, one for XCOM's turn and one for Advent' turn. If both are provided they will be handed off as appropriate while the definition is active.

  -Wwise Mms Definitions-

  	Wwise Mms definitions are significantly more complex than MMS definitions, comensurate with their advanced capabilities. They do not contain references to tracks, or an explicit listing of when they should be played. Instead, Wwise Mms definitions contain defined "start" and "transition" strings. Each string is the path to a UE3 "AkEvent" object within a .UPK package file. These events are dummy objects which UE3 uses to reference events which the modder has created using the Wwise authoring tools. An event can do a wide variety of things such as starting another track, changing the volume or applying an audio filter. 

  	When deciding whether or not a Wwise Mms definition can be randomly selected for a particular gameplay state, the system checks to see if there is a string stored in the relevent variable (i.e. Geoscape_StartEventPath). If the string is not empty then that definition is considered valid. Because "start" and "transition" events are differentiated, it is possible to have a definition which can transition to a gameplay state but not be started there (or vice-versa).

  	Wwise Mms definitions also contain optional event paths which can modify the music if the modder desires. In some cases this is the path to a single event which is called at a clearly defined time (i.e. ScanningCompleted_EventPath). Other times there is a single dimension array of strings which will be checked against an integer and used as described in the modding documentation (i.e. DeadSoldierCount_EventPaths). In a third case, some events are stored in a single dimension array of the "NameAndPath" class which can be checked against a string and called as described in the modding documentation. The behaviour of these event lists cannot be defined in general because their behaviour is dictated by their function.

	Wwise Mms definitions also have the following optional variables which do not apply to MMS definitions:

		(int) Lifespan: If more than this many seconds have passed since the definition was initiated then it will be stopped and replaced at the next music state change, regardless of whether or not it contains a transition event.

  		(string) Append: All path name strings within the definition will be treated as though they start with this string. This is purely a convenience feature which reduces repeated text and makes config files clearer.

  		(string) End_EventPath: The event to be called when a Wwise Mms definition is stopped.

  	-Common Variables-

  		Music definitions also contain a few generally descriptive variables:

  			(string) MusicID:  Used to keep track of music definitions across multiple copies and between sound managers. Modders are responsible for keeping this variable unique.

  			(bool) isAssigned: Used internally to identify definition objects which are part of the full music definition list.

  			(bool) wwiseEnabled: Used internally to identify whether a definition contains MMS or WwiseMms data. Any data from the other format will be ignored.


*** Lifecycle of Music Playback ***

	When a sound manager is created it reads in two sets of music definitions from any relevent config files; one set from mods designed for the original MMS, one from mods designed for Wwise Mms. These are then compiled into a single list which will be selected from whenever a new piece of music is required. The manager identifies which of those definitions are relevent to the current situation and selects one at random. For legacy reasons, the tactical sound manager keeps a buffer of random music definitions for both explore and combat modes.

		EXCEPTION: Under circumstances detailed elsewhere in this document, there may be handover between sound managers. In this situation the sound manager tries to find and play the definition which has been passed instead of randomly selecting one. If it does not succeed it will revert to normal behaviour.

	Music playback is performed by helper classes which are instatiated once by the sound manager and then stored for future use. Wwise Mms and MMS definitions are played using different classes which are set up for their respective audio systems. For legacy reasons there are four MMS music player objects for the tactical mode which hand off depending on the tactical state (explore or combat) and currently active turn (XCOM or Advent).

	Within the strategy and tactical game modes there are various situations which call for different music tracks. Like MMS, Wwise Mms uses the same delineations as the unmodified game's music. For example, in strategy when the player goes from the base "ant farm" screen to the geoscape screen a new track will be initiated (the full list of these can be found in the music pack development documentation). If an MMS definition is currently playing, it will always be changed for a new definition (potentially MMS or Wwise Mms) when a track change is called for. If a Wwise Mms definition is currently playing, the following decision process occurs:

			IF: the current definition has been playing for longer than the number of seconds in its "lifespan" variable, stop the music player and start a new random definition. This prevents single definitions for playing infinitely.

			ELSE IF: the current definition contains a "transition" event to the new game state, call that event. There is no check to ensure that the name of the provided event is valid. An invalid event name is not catastrophic because it will neither stop, nor change, music playback.
			
			ELSE: stop the current definition and start a new one.

	When a music player object is asked to stop, it will either fade itself out or call a stop event if one is provided by a Wwise Mms definition. Music players store their stop events as direct references to Wwise events so they will never try to call an invalid event name. However, the music pack creator is responsible for ensuring that the stop event does in fact stop music playback. Failure to do so will generally lead to playback of two tracks simultaneously.
