class Wwise_Mms_SeqAct_PlayDropshipSound extends MMS_SeqAct_PlayDropshipSound;

//----------------------------------------------------------------------------------------------------------------------------Event - Activated
event Activated(){

	//local Wwise_Mms_XComTacticalSoundManager Mgr;
	//
	//Mgr = Wwise_Mms_XComTacticalSoundManager(`XTACTICALSOUNDMGR);	
	//Mgr.WwiseMms_PlayDropshipMusic();

	//The dropship is dead.
}

//----------------------------------------------------------------------------------------------------------------------------DefaultProperties
defaultproperties
{
	ObjName="Play Dropship Sound"
	ObjCategory="Music"
	ObjColor=(R=255,G=100,B=100,A=255)

	bConvertedForReplaySystem=true
	bCanBeUsedForGameplaySequence=true
	bAutoActivateOutputLinks=true
}