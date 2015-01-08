// ---- Preprocessor -----------------------------------------------------------
#pragma semicolon 1 

// ---- Includes ---------------------------------------------------------------
#include <sourcemod>
#include <morecolors>
#include <tf2_stocks>
#include <tf2items>
#include <steamtools>
#include <clientprefs>

// ---- Defines ----------------------------------------------------------------
#define DR_VERSION "0.1.6"
#define PLAYERCOND_SPYCLOAK (1<<4)
#define MAXGENERIC 25	//Used as a limit in the config file

#define TEAM_RED 2
#define TEAM_BLUE 3
//#define RUNNER_SPEED 300.0
//#define DEATH_SPEED 400.0
//#define MELEE_NUMBER 10
//new melee_vec[] =  {264 ,423 ,474, 880, 939, 954, 1013, 1071, 1123, 1127};
// Frying Pan, Saxxy, The Conscientious Objector, The Freedom Staff, The Bat Outta Hell, The Memory Maker, The Ham Shank, Gold Frying Pan, The Necro Smasher, The Crossing Guard
#define DBD_UNDEF -1 //DBD = Don't Be Death
#define DBD_OFF 1
#define DBD_ON 2
#define DBD_THISMAP 3 // The cookie will never have this value
#define TIME_TO_ASK 30.0 //Delay between asking the client its preferences and it's connection/join.


// ---- Variables --------------------------------------------------------------
new bool:g_isDRmap = false;
new g_lastdeath = -1;
new g_timesplayed_asdeath[MAXPLAYERS+1];
new bool:g_onPreparation = false;
new g_dontBeDeath[MAXPLAYERS+1] = {DBD_UNDEF,...};
new bool:g_canEmitSoundToDeath = true;

//GenerealConfig
new bool:g_diablefalldamage;
new Float:g_runner_speed;
new Float:g_death_speed;
new g_runner_outline;
new g_death_outline;

//Weapon-config
new bool:g_MeleeOnly;
new bool:g_MeleeRestricted;
new bool:g_RestrictAll;
new Handle:g_RestrictedWeps;
new bool:g_UseDefault;
new bool:g_UseAllClass;
new Handle:g_AllClassWeps;

//Command-config
new Handle:g_CommandToBlock;
new Handle:g_BlockOnlyOnPreparation;

//Sound-config
new Handle:g_SndRoundStart;
new Handle:g_SndOnDeath;
new Float: g_OnKillDelay;
new Handle:g_SndOnKill;
new Handle:g_SndLastAlive;



// ---- Handles ----------------------------------------------------------------
new Handle:g_DRCookie = INVALID_HANDLE;

// ---- Plugin's CVars Management ----------------------------------------------
/*
new g_Enabled;
new g_Outlines;
new g_MeleeOnly;
new g_MeleeType;

new Handle:dr_Enabled;
new Handle:dr_Outlines;
new Handle:dr_MeleeOnly;
new Handle:dr_MeleeType;
*/
// ---- Server's CVars Management ----------------------------------------------
new Handle:dr_queue;
new Handle:dr_unbalance;
new Handle:dr_autobalance;
new Handle:dr_firstblood;
new Handle:dr_scrambleauto;
new Handle:dr_airdash;
new Handle:dr_push;

new dr_queue_def = 0;
new dr_unbalance_def = 0;
new dr_autobalance_def = 0;
new dr_firstblood_def = 0;
new dr_scrambleauto_def = 0;
new dr_airdash_def = 0;
new dr_push_def = 0;

// ---- Plugin's Information ---------------------------------------------------
public Plugin:myinfo =
{
	name = "[TF2] Deathrun Redux",
	author = "Classic",
	description	= "Deathrun plugin for TF2",
	version = DR_VERSION,
	url = "http://www.clangs.com.ar"
};

/* OnPluginStart()
**
** When the plugin is loaded.
** -------------------------------------------------------------------------- */
public OnPluginStart()
{
	//Cvars
	CreateConVar("sm_dr_version", DR_VERSION, "Death Run Redux Version.", FCVAR_REPLICATED | FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	/*
	dr_Enabled = CreateConVar("sm_dr_enabled",	"1", "Enables / Disables the Death Run Redux plugin.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dr_Outlines = CreateConVar("sm_dr_outlines",	"1", "Enables / Disables ability to players from runners team be seen throught walls by outline", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dr_MeleeOnly = CreateConVar("sm_dr_melee_only",	"1", "Enables / Disables the exclusive use of melee weapons",FCVAR_PLUGIN, true, 0.0, true, 1.0);
	dr_MeleeType = CreateConVar("sm_dr_melee_type",	"1", "Type of melee restriction. 0: No restriction. 1: Gives default weapon to player's class.\n2: Gives all-class weapons. Only works if sm_dr_melee_only is in 1.",FCVAR_PLUGIN, true, 0.0, true, 2.0);
	*/
	
	//Defaults variables values
	/*
	g_Enabled = GetConVarInt(dr_Enabled);
	g_Outlines = GetConVarInt(dr_Outlines);
	g_MeleeOnly = GetConVarInt(dr_MeleeOnly);
	g_MeleeType = GetConVarInt(dr_MeleeType);
	*/
	
	//Creation of Tries
	g_RestrictedWeps = CreateTrie();
	g_AllClassWeps = CreateTrie();
	g_CommandToBlock = CreateTrie();
	g_BlockOnlyOnPreparation = CreateTrie();
	g_SndRoundStart = CreateTrie();
	g_SndOnDeath = CreateTrie();
	g_SndOnKill = CreateTrie();
	g_SndLastAlive = CreateTrie();
	
	//Server's Cvars
	dr_queue = FindConVar("tf_arena_use_queue");
	dr_unbalance = FindConVar("mp_teams_unbalance_limit");
	dr_autobalance = FindConVar("mp_autoteambalance");
	dr_firstblood = FindConVar("tf_arena_first_blood");
	dr_scrambleauto = FindConVar("mp_scrambleteams_auto");
	dr_airdash = FindConVar("tf_scout_air_dash_count");
	dr_push = FindConVar("tf_avoidteammates_pushaway");
	
	//Cvars's hook
	/*
	HookConVarChange(dr_Enabled, OnCVarChange);
	HookConVarChange(dr_Outlines, OnCVarChange);
	HookConVarChange(dr_MeleeOnly, OnCVarChange);
	HookConVarChange(dr_MeleeType, OnCVarChange);
	*/

	//Hooks
	HookEvent("teamplay_round_start", OnPrepartionStart);
	HookEvent("arena_round_start", OnRoundStart); 
	HookEvent("post_inventory_application", OnPlayerInventory);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	
	//AddCommandListener(Command_Block,"build");
	//AddCommandListener(Command_Block,"kill");
	//AddCommandListener(Command_Play1,"explode");
	
	//AutoExecConfig(true, "plugin.deathrun_redux");
	
	//Preferences
	g_DRCookie = RegClientCookie("DR_dontBeDeath", "Does the client want to be the Death?", CookieAccess_Private);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;
		OnClientCookiesCached(i);
	}
	RegConsoleCmd( "drtoggle",  BeDeathMenu);
}

/* OnPluginEnd()
**
** When the plugin is unloaded. Here we reset all the cvars to their normal value.
** -------------------------------------------------------------------------- */
public OnPluginEnd()
{
	ResetCvars();
}

/* OnCVarChange()
**
** We edit the global variables values when their corresponding cvar changes.
** -------------------------------------------------------------------------- */
/*
public OnCVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(convar == dr_Enabled) 
		g_Enabled = GetConVarInt(dr_Enabled);
	else if(convar == dr_Outlines) 
		g_Outlines = GetConVarInt(dr_Outlines);
	else if(convar == dr_MeleeOnly) 
		g_MeleeOnly = GetConVarInt(dr_MeleeOnly);
	else if(convar == dr_MeleeType) 
		g_MeleeType = GetConVarInt(dr_MeleeType);
}
*/

/* OnMapStart()
**
** Here we reset every global variable, and we check if the current map is a deathrun map.
** If it is a dr map, we get the cvars def. values and the we set up our own values.
** -------------------------------------------------------------------------- */
public OnMapStart()
{
	g_lastdeath = -1;
	for(new i = 1; i <= MaxClients; i++)
			g_timesplayed_asdeath[i]=-1;
			
	decl String:mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	if (strncmp(mapname, "dr_", 3, false) == 0 || strncmp(mapname, "deathrun_", 9, false) == 0 || strncmp(mapname, "vsh_dr", 6, false) == 0 || strncmp(mapname, "vsh_deathrun", 6, false) == 0)
	{
		LogMessage("Deathrun map detected. Enabling Deathrun Gamemode.");
		g_isDRmap = true;
		Steam_SetGameDescription("DeathRun Redux");
		AddServerTag("deathrun");
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!AreClientCookiesCached(i))
				continue;
			OnClientCookiesCached(i);
		}
		LoadConfigs();
		PrecacheFiles();
		ProcessListeners();
	}
 	else
	{
		LogMessage("Current map is not a deathrun map. Disabling Deathrun Gamemode.");
		g_isDRmap = false;
		Steam_SetGameDescription("Team Fortress");	
		RemoveServerTag("deathrun");
	}
}

/* OnMapEnd()
**
** Here we reset the server's cvars to their default values.
** -------------------------------------------------------------------------- */
public OnMapEnd()
{
	ResetCvars();
	for (new i = 1; i <= MaxClients; i++)
	{
		g_dontBeDeath[i] = DBD_UNDEF;
	}
}

/* LoadConfigs()
**
** Here we parse the data/deathrun/deathrun.cfg
** -------------------------------------------------------------------------- */
LoadConfigs()
{
	//--DEFAULT VALUES--
	//GenerealConfig
	g_diablefalldamage = false;
	g_runner_speed = 300.0;
	g_death_speed = 400.0;
	g_runner_outline = 0;
	g_death_outline = -1;

	//Weapon-config
	g_MeleeOnly = true;
	g_MeleeRestricted = true;
	g_RestrictAll = true;
	ClearTrie(g_RestrictedWeps);
	g_UseDefault = true;
	g_UseAllClass = false;
	ClearTrie(g_AllClassWeps);

	//Command-config
	ClearTrie(g_CommandToBlock);
	ClearTrie(g_BlockOnlyOnPreparation);

	//Sound-config
	ClearTrie(g_SndRoundStart);
	ClearTrie(g_SndOnDeath);
	g_OnKillDelay = 5.0;
	ClearTrie(g_SndOnKill);
	ClearTrie(g_SndLastAlive);
	
	decl String:mainfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mainfile, sizeof(mainfile), "data/deathrun/deathrun.cfg");
	
	if(!FileExists(mainfile))
	{
		SetFailState("Configuration file %s not found!", mainfile);
		return;
	}
	new Handle:hDR = CreateKeyValues("deathrun");
	if(!FileToKeyValues(hDR, mainfile))
	{
		SetFailState("Improper structure for configuration file %s!", mainfile);
		return;
	}
	if(KvJumpToKey(hDR,"default"))
	{
		g_diablefalldamage = bool:KvGetNum(hDR, "DisableFallDamage", _:g_diablefalldamage);

		if(KvJumpToKey(hDR,"speed"))
		{
			g_runner_speed = KvGetFloat(hDR,"runners",g_runner_speed);
			g_death_speed = KvGetFloat(hDR,"death",g_death_speed);
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"outline"))
		{
			g_runner_outline = KvGetNum(hDR,"runners",g_runner_outline);
			g_death_outline = KvGetNum(hDR,"death",g_death_outline);
			KvGoBack(hDR);
		}
		KvGoBack(hDR);
	}
	
	
	KvRewind(hDR);
	if(KvJumpToKey(hDR,"weapons"))
	{
	
		g_MeleeOnly = bool:KvGetNum(hDR, "MeleeOnly", _:g_MeleeOnly);
		if(g_MeleeOnly)
		{
			g_MeleeRestricted = bool:KvGetNum(hDR, "RestrictedMelee",_:g_MeleeRestricted);
			if(g_MeleeRestricted)
			{
				KvJumpToKey(hDR,"MeleeRestriction");
				g_RestrictAll = bool:KvGetNum(hDR, "RestrictAll", _:g_RestrictAll);
				if(!g_RestrictAll)
				{
					KvJumpToKey(hDR,"RestrictedWeapons");
					new String:key[4], auxInt;
					for(new i=1; i<MAXGENERIC; i++)
					{
						IntToString(i, key, sizeof(key));
						auxInt = KvGetNum(hDR, key, -1);
						if(auxInt == -1)
						{
							break;
						}
						SetTrieValue(g_RestrictedWeps,key,auxInt);
					}
					KvGoBack(hDR);
				}
				g_UseDefault = bool:KvGetNum(hDR, "UseDefault", _:g_UseDefault);
				g_UseAllClass = bool:KvGetNum(hDR, "UseAllClass", _:g_UseAllClass);
				if(g_UseAllClass)
				{
					KvJumpToKey(hDR,"AllClassWeapons");
					new String:key[4], auxInt;
					for(new i=1; i<MAXGENERIC; i++)
					{
						IntToString(i, key, sizeof(key));
						auxInt = KvGetNum(hDR, key, -1);
						if(auxInt == -1)
						{
							break;
						}
						SetTrieValue(g_AllClassWeps,key,auxInt);
					}
					KvGoBack(hDR);
				}
				KvGoBack(hDR);
			}
			
		}
	}
	
	KvRewind(hDR);
	KvJumpToKey(hDR,"blockcommands");
	do
	{
		decl String:SectionName[128],String:CommandName[128],bool:onprep;
		KvGotoFirstSubKey(hDR);
		KvGetSectionName(hDR, SectionName, sizeof(SectionName));
		
		KvGetString(hDR, "command", CommandName, sizeof(CommandName));
		onprep = bool:KvGetNum(hDR, "OnlyOnPreparation", 0);
		
		if(!StrEqual(CommandName, ""))
		{
			SetTrieString(g_CommandToBlock,SectionName,CommandName);
			SetTrieValue(g_BlockOnlyOnPreparation,SectionName,_:onprep);
		}
	}
	while(KvGotoNextKey(hDR));
	
	KvRewind(hDR);
	if(KvJumpToKey(hDR,"sounds"))
	{
		new String:key[4], String:sndFile[PLATFORM_MAX_PATH];
		if(KvJumpToKey(hDR,"RoundStart"))
		{
			for(new i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndRoundStart,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"OnDeath"))
		{
			for(new i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndOnDeath,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"OnKill"))
		{
			
			g_OnKillDelay = KvGetFloat(hDR,"delay",g_OnKillDelay);
			for(new i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndOnKill,key,sndFile);
			}
			KvGoBack(hDR);
		}
		
		if(KvJumpToKey(hDR,"LastAlive"))
		{
			for(new i=1; i<MAXGENERIC; i++)
			{
				IntToString(i, key, sizeof(key));
				KvGetString(hDR, key, sndFile, sizeof(sndFile),"");
				if(StrEqual(sndFile, ""))
					break;			
				SetTrieString(g_SndLastAlive,key,sndFile);
			}
			KvGoBack(hDR);
		}
		KvGoBack(hDR);
	}
	
	KvRewind(hDR);
	CloseHandle(hDR);
	
	decl String:mapfile[PLATFORM_MAX_PATH],String:mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	BuildPath(Path_SM, mapfile, sizeof(mapfile), "data/deathrun/maps/%s.cfg",mapname);
	if(FileExists(mapfile))
	{
		hDR = CreateKeyValues("drmap");
		if(!FileToKeyValues(hDR, mapfile))
		{
			SetFailState("Improper structure for configuration file %s!", mapfile);
			return;
		}
		
		g_diablefalldamage = bool:KvGetNum(hDR, "DisableFallDamage", _:g_diablefalldamage);

		if(KvJumpToKey(hDR,"speed"))
		{
			g_runner_speed = KvGetFloat(hDR,"runners",g_runner_speed);
			g_death_speed = KvGetFloat(hDR,"death",g_death_speed);
			
			KvGoBack(hDR);
		}
		if(KvJumpToKey(hDR,"outline"))
		{
			g_runner_outline = KvGetNum(hDR,"runners",g_runner_outline);
			g_death_outline = KvGetNum(hDR,"death",g_death_outline);
		}
		KvRewind(hDR);
		CloseHandle(hDR);
	}

}


/* PrecacheFiles()
**
** We precache and add to the download table every sound file found on the config file.
** -------------------------------------------------------------------------- */
PrecacheFiles()
{
	PrecacheSoundFromTrie(g_SndRoundStart);
	PrecacheSoundFromTrie(g_SndOnDeath);
	PrecacheSoundFromTrie(g_SndOnKill);
	PrecacheSoundFromTrie(g_SndLastAlive);
}

/* PrecacheFiles()
**
** We precache and add to the download table, reading every value of a Trie.
** -------------------------------------------------------------------------- */
PrecacheSoundFromTrie(Handle:sndTrie)
{
	new trieSize = GetTrieSize(sndTrie);
	decl String:soundString[PLATFORM_MAX_PATH],String:downloadString[PLATFORM_MAX_PATH],String:key[4];
	for(new i = 1; i <= trieSize; i++)
	{
		IntToString(i,key,sizeof(key));
		if(GetTrieString(sndTrie,key,soundString, sizeof(soundString)))
		{
			if(PrecacheSound(soundString))
			{
				Format(downloadString, sizeof(downloadString), "sound/%s", soundString);
				AddFileToDownloadsTable(downloadString);
			}
		}
	}
}


/* ProcessListeners()
**
** Here we add the listeners to block the commands defined on the config file.
** -------------------------------------------------------------------------- */
ProcessListeners(bool:removeListerners=false)
{
	new trieSize = GetTrieSize(g_CommandToBlock);
	decl String:command[PLATFORM_MAX_PATH],String:key[4],PreparationOnly;
	for(new i = 1; i <= trieSize; i++)
	{
		IntToString(i,key,sizeof(key));
		if(GetTrieString(g_CommandToBlock,key,command, sizeof(command)))
		{
			if(StrEqual(command, ""))
					break;		
					
			GetTrieValue(g_BlockOnlyOnPreparation,key,PreparationOnly);
			if(removeListerners)
			{
				if(PreparationOnly == 1)
					RemoveCommandListener(Command_Block_PreparationOnly,command);
				else
					RemoveCommandListener(Command_Block,command);
			}
			else
			{
				if(PreparationOnly == 1)
					AddCommandListener(Command_Block_PreparationOnly,command);
				else
					AddCommandListener(Command_Block,command);
			}
			
			
		}
	}
}

/* OnClientPutInServer()
**
** We set on zero the time played as death when the client enters the server.
** -------------------------------------------------------------------------- */
public OnClientPutInServer(client)
{
	g_timesplayed_asdeath[client] = 0;
}

/* OnClientDisconnect()
**
** We set as minus one the time played as death when the client leaves.
** When searching for a Death we ignore every client with the -1 value.
** We also set as undef the preference value
** -------------------------------------------------------------------------- */
public OnClientDisconnect(client)
{
	g_timesplayed_asdeath[client] =-1;
	g_dontBeDeath[client] = DBD_UNDEF;
}

/* OnClientCookiesCached()
**
** We look if the client have a saved value
** -------------------------------------------------------------------------- */
public OnClientCookiesCached(client)
{
	decl String:sValue[8];
	GetClientCookie(client, g_DRCookie, sValue, sizeof(sValue));
	new nValue = StringToInt(sValue);

	if( nValue != DBD_OFF && nValue != DBD_ON) //If cookie is not valid we ask for a preference.
		CreateTimer(TIME_TO_ASK, AskMenuTimer, client);
	else //client has a valid cookie
		g_dontBeDeath[client] = nValue;
}

public Action:AskMenuTimer(Handle:timer, any:client)
{
	BeDeathMenu(client,0);
}

public Action:BeDeathMenu(client,args)
{
	if (client == 0 || (!IsClientInGame(client)))
	{
		return Plugin_Handled;
	}
	new Handle:menu = CreateMenu(BeDeathMenuHandler);
	SetMenuTitle(menu, "Be the Death toggle");
	AddMenuItem(menu, "0", "Select me as Death");
	AddMenuItem(menu, "1", "Don't select me as Death");
	AddMenuItem(menu, "2", "Don't be Death in this map");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 30);
	
	return Plugin_Handled;
}

public BeDeathMenuHandler(Handle:menu, MenuAction:action, client, buttonnum)
{
	if (action == MenuAction_Select)
	{
		if (buttonnum == 0)
		{
			g_dontBeDeath[client] = DBD_OFF;
			decl String:sPref[2];
			IntToString(DBD_OFF, sPref, sizeof(sPref));
			SetClientCookie(client, g_DRCookie, sPref);
			CPrintToChat(client,"{black}[DR]{DEFAULT} You can be selected as Death.");
		}
		else if (buttonnum == 1)
		{
			g_dontBeDeath[client] = DBD_ON;
			decl String:sPref[2];
			IntToString(DBD_ON, sPref, sizeof(sPref));
			SetClientCookie(client, g_DRCookie, sPref);
			CPrintToChat(client,"{black}[DR]{DEFAULT} You can't be selected as Death.");
		}
		else if (buttonnum == 2)
		{
			g_dontBeDeath[client] = DBD_THISMAP;
			CPrintToChat(client,"{black}[DR]{DEFAULT} You can't be selected as Death for this map.");
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/* OnPrepartionStart()
**
** We setup the cvars again, balance the teams and we freeze the players.
** -------------------------------------------------------------------------- */
public Action:OnPrepartionStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_isDRmap)
	{
		g_onPreparation = true;
		
		//We force the cvars values needed every round (to override if any cvar was changed).
		SetupCvars();
		
		//We move the players to the corresponding team.
		BalanceTeams();
		
		//Players shouldn't move until the round starts
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && IsPlayerAlive(i))
				SetEntityMoveType(i, MOVETYPE_NONE);	

		EmitRandomSound(g_SndRoundStart);
	}
}

/* OnRoundStart()
**
** We unfreeze every player.
** -------------------------------------------------------------------------- */
public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_isDRmap)
	{
		for(new i = 1; i <= MaxClients; i++)
			if(IsClientInGame(i) && IsPlayerAlive(i))
					SetEntityMoveType(i, MOVETYPE_WALK);
		g_onPreparation = false;
	}
}

/* TF2Items_OnGiveNamedItem_Post()
**
** Here we check for the demoshield and the sapper.
** -------------------------------------------------------------------------- */
public TF2Items_OnGiveNamedItem_Post(client, String:classname[], index, level, quality, ent)
{
	if(g_isDRmap && g_MeleeOnly)
	{
		//tf_weapon_builder tf_wearable_demoshield
		if(StrEqual(classname,"tf_weapon_builder", false) || StrEqual(classname,"tf_wearable_demoshield", false))
			CreateTimer(0.1, Timer_RemoveWep, EntIndexToEntRef(ent));  
	}
}

/* Timer_RemoveWep()
**
** We kill the demoshield/sapper
** -------------------------------------------------------------------------- */
public Action:Timer_RemoveWep(Handle:timer, any:ref)
{
	new ent = EntRefToEntIndex(ref);
	if( IsValidEntity(ent) && ent > MaxClients)
		AcceptEntityInput(ent, "Kill");
}  

/* OnPlayerInventory()
**
** Here we strip players weapons (if we have to).
** Also we give special melee weapons (again, if we have to).
** -------------------------------------------------------------------------- */
public Action:OnPlayerInventory(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_isDRmap)
	{
		if(g_MeleeOnly)
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
			
			
			if(g_MeleeRestricted)
			{
				new bool:replacewep = false;
				if(g_RestrictAll)
					replacewep=true;
				else
				{
					new wepIndex = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
					new rwSize = GetTrieSize(g_RestrictedWeps);
					new String:key[4], auxIndex;
					for(new i = 1; i <= rwSize; i++)
					{
						IntToString(i,key,sizeof(key));
						if(GetTrieValue(g_RestrictedWeps,key,auxIndex))
							if(wepIndex == auxIndex)
								replacewep=true;
					}
				
				}
				if(replacewep)
				{
					TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
					new weaponToUse = -1;
					if(g_UseAllClass)
					{
						new acwSize = GetTrieSize(g_AllClassWeps);
						new rndNum;
						if(g_UseDefault)
							rndNum = GetRandomInt(1,acwSize+1);
						else
							rndNum = GetRandomInt(1,acwSize);
						
						if(rndNum <= acwSize)
						{
							new String:key[4];
							IntToString(rndNum,key,sizeof(key));
							GetTrieValue(g_AllClassWeps,key,weaponToUse);
						}
						
					}
					new Handle:hItem = TF2Items_CreateItem(FORCE_GENERATION | OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF | OVERRIDE_ITEM_LEVEL | OVERRIDE_ITEM_QUALITY | OVERRIDE_ATTRIBUTES);
					
					//Here we give a melee to every class
					new TFClassType:iClass = TF2_GetPlayerClass(client);
					switch(iClass)
					{
						case TFClass_Scout:{
							TF2Items_SetClassname(hItem, "tf_weapon_bat");
							if(weaponToUse == -1)
								weaponToUse = 190;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Sniper:{
							TF2Items_SetClassname(hItem, "tf_weapon_club");
							if(weaponToUse == -1)
								weaponToUse = 190;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							TF2Items_SetItemIndex(hItem, 193);
							}
						case TFClass_Soldier:{
							TF2Items_SetClassname(hItem, "tf_weapon_shovel");
							if(weaponToUse == -1)
								weaponToUse = 196;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_DemoMan:{
							TF2Items_SetClassname(hItem, "tf_weapon_bottle");
							if(weaponToUse == -1)
								weaponToUse = 191;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Medic:{
							TF2Items_SetClassname(hItem, "tf_weapon_bonesaw");
							if(weaponToUse == -1)
								weaponToUse = 198;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Heavy:{
							TF2Items_SetClassname(hItem, "tf_weapon_fists");
							if(weaponToUse == -1)
								weaponToUse = 195;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Pyro:{
							TF2Items_SetClassname(hItem, "tf_weapon_fireaxe");
							if(weaponToUse == -1)
								weaponToUse = 192;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Spy:{
							TF2Items_SetClassname(hItem, "tf_weapon_knife");
							if(weaponToUse == -1)
								weaponToUse = 194;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						case TFClass_Engineer:{
							TF2Items_SetClassname(hItem, "tf_weapon_wrench");
							if(weaponToUse == -1)
								weaponToUse = 197;
							TF2Items_SetItemIndex(hItem, weaponToUse);
							}
						}
							
					TF2Items_SetLevel(hItem, 69);
					TF2Items_SetQuality(hItem, 6);
					TF2Items_SetAttribute(hItem, 0, 150, 1.0); //Turn to gold on kill
					TF2Items_SetNumAttributes(hItem, 1);
					new iWeapon = TF2Items_GiveNamedItem(client, hItem);
					CloseHandle(hItem);
					
					EquipPlayerWeapon(client, iWeapon);
					TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
				}
			}
		}
	}
}

/* OnPlayerSpawn()
**
** Here we enable the glow (if we need to), we set the spy cloak and we move the death player.
** -------------------------------------------------------------------------- */
public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_isDRmap)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if((GetClientTeam(client) == TEAM_RED && g_runner_outline == 0)||(GetClientTeam(client) == TEAM_BLUE && g_death_outline == 0))
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
		}
		
		if(g_MeleeOnly)
		{
			new cond = GetEntProp(client, Prop_Send, "m_nPlayerCond");
			
			if (cond & PLAYERCOND_SPYCLOAK)
			{
				SetEntProp(client, Prop_Send, "m_nPlayerCond", cond | ~PLAYERCOND_SPYCLOAK);
			}
		}
		
		if(GetClientTeam(client) == TEAM_BLUE && client != g_lastdeath)
		{
			ChangeClientTeam(client, TEAM_RED);
			CreateTimer(0.2, RespawnRebalanced,  GetClientUserId(client));
		}
		
		if(g_onPreparation)
			SetEntityMoveType(client, MOVETYPE_NONE);	
		
	}
}


/* OnPlayerDeath()
**
** Here we reproduce sounds if needed
** -------------------------------------------------------------------------- */
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_isDRmap)
	{
		if(!g_onPreparation)
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));
			new aliveRunners = GetAlivePlayersCount(TEAM_RED,client);
			
			if(GetClientTeam(client) == TEAM_RED && aliveRunners > 0)
				EmitRandomSound(g_SndOnDeath,client);
				
			if(aliveRunners == 1)
				EmitRandomSound(g_SndLastAlive,GetLastPlayer(TEAM_RED,client));
				
			if(g_canEmitSoundToDeath)
			{
				EmitRandomSound(g_SndOnKill,GetLastPlayer(TEAM_BLUE));
				g_canEmitSoundToDeath = false;
				CreateTimer(g_OnKillDelay, ReenableDeathSound);
			}
			
		}
		
	}
}


public Action:ReenableDeathSound(Handle:timer, any:data)
{
	g_canEmitSoundToDeath = true;
}


/* BalanceTeams()
**
** Moves players to their new team in this round.
** -------------------------------------------------------------------------- */
stock BalanceTeams()
{
	if(GetClientCount(true) > 1)
	{
		new new_death = GetRandomValid();
		if(new_death == -1)
		{
			CPrintToChatAll("{black}[DR]{DEFAULT} Couldn't found a valid Death.");
			return;
		}
		g_lastdeath  = new_death;
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsClientConnected(i))
			{
				if(i == new_death)
				{
					if(GetClientTeam(i) != TEAM_BLUE)
					ChangeClientTeam(i, TEAM_BLUE);
					
					new TFClassType:iClass = TF2_GetPlayerClass(i);
					if (iClass == TFClass_Unknown)
					{
						TF2_SetPlayerClass(i, TFClass_Scout, false, true);
					}
				}
				else if(GetClientTeam(i) != TEAM_RED )
				{
					ChangeClientTeam(i, TEAM_RED);
				}
				CreateTimer(0.2, RespawnRebalanced,  GetClientUserId(i));
			}
		}
		if(!IsClientConnected(new_death) || !IsClientInGame(new_death)) 
		{
			CPrintToChatAll("{black}[DR]{DEFAULT} Death isn't in game.");
			return;
		}
		
		CPrintToChatAll("{black}[DR]{gold}%N {DEFAULT}is the Death", new_death);
		g_timesplayed_asdeath[g_lastdeath]++;

	}
	else
	{
		CPrintToChatAll("{black}[DR]{DEFAULT} This game-mode requires at least two people to start");
	}
}

/* GetRandomValid()
**
** Gets a random player that didn't play as death recently.
** -------------------------------------------------------------------------- */
public GetRandomValid()
{
	new possiblePlayers[MAXPLAYERS+1];
	new possibleNumber = 0;
	
	new min = GetMinTimesPlayed(false);
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i) || !IsClientInGame(i))
			continue;
		if(g_timesplayed_asdeath[i] != min)
			continue;
		if(g_dontBeDeath[i] == DBD_ON || g_dontBeDeath[i] == DBD_THISMAP)
			continue;
		
		possiblePlayers[possibleNumber] = i;
		possibleNumber++;
		
	}
	
	//If there are zero people available we ignore the preferences.
	if(possibleNumber == 0)
	{
		min = GetMinTimesPlayed(true);
		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsClientConnected(i) || !IsClientInGame(i) )
				continue;
			if(g_timesplayed_asdeath[i] != min)
				continue;			
			possiblePlayers[possibleNumber] = i;
			possibleNumber++;
		}
		if(possibleNumber == 0)
			return -1;
	}
	
	return possiblePlayers[ GetRandomInt(0,possibleNumber-1)];

}

/* GetMinTimesPlayed()
**
** Get the minimum "times played", if ignorePref is true, we ignore the don't be death preference
** -------------------------------------------------------------------------- */
GetMinTimesPlayed(bool:ignorePref)
{
	new min = -1;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i) || !IsClientInGame(i) || g_timesplayed_asdeath[i] == -1) 
			continue;
		if(i == g_lastdeath) 
			continue;
		if(!ignorePref)
			if(g_dontBeDeath[i] == DBD_ON || g_dontBeDeath[i] == DBD_THISMAP)
				continue;
		if(min == -1)
			min = g_timesplayed_asdeath[i];
		else
			if(min > g_timesplayed_asdeath[i])
				min = g_timesplayed_asdeath[i];
		
	}
	return min;

}

/* OnGameFrame()
**
** We set the player max speed on every frame, and also we set the spy's cloak on empty.
** -------------------------------------------------------------------------- */
public OnGameFrame()
{
	if(g_isDRmap)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i) == TEAM_RED )
					SetEntPropFloat(i, Prop_Send, "m_flMaxspeed", g_runner_speed);
				else if(GetClientTeam(i) == TEAM_BLUE)
					SetEntPropFloat(i, Prop_Send, "m_flMaxspeed", g_death_speed);
					
				if(g_MeleeOnly)
					if(TF2_GetPlayerClass(i) == TFClass_Spy)
						SetCloak(i, 1.0);
			}
		}
	}
}

/* TF2_SwitchtoSlot()
**
** Changes the client's slot to the desired one.
** -------------------------------------------------------------------------- */
stock TF2_SwitchtoSlot(client, slot)
{
	if (slot >= 0 && slot <= 5 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		decl String:classname[64];
		new wep = GetPlayerWeaponSlot(client, slot);
		if (wep > MaxClients && IsValidEdict(wep) && GetEdictClassname(wep, classname, sizeof(classname)))
		{
			FakeClientCommandEx(client, "use %s", classname);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
		}
	}
}

/* SetCloak()
**
** Function used to set the spy's cloak meter.
** -------------------------------------------------------------------------- */
stock SetCloak(client, Float:value)
{
	SetEntPropFloat(client, Prop_Send, "m_flCloakMeter", value);
}

/* RespawnRebalanced()
**
** Timer used to spawn a client if he/she is in game and if it isn't alive.
** -------------------------------------------------------------------------- */
public Action:RespawnRebalanced(Handle:timer, any:data)
{
	new client = GetClientOfUserId(data);
	if(IsClientInGame(client))
	{
		if(!IsPlayerAlive(client))
		{
			TF2_RespawnPlayer(client);
		}
	}
}

/* OnConfigsExecuted()
**
** Here we get the default values of the CVars that the plugin is going to modify.
** -------------------------------------------------------------------------- */
public OnConfigsExecuted()
{
	dr_queue_def= GetConVarInt(dr_queue);
	dr_unbalance_def = GetConVarInt(dr_unbalance);
	dr_autobalance_def = GetConVarInt(dr_autobalance);
	dr_firstblood_def = GetConVarInt(dr_firstblood);
	dr_scrambleauto_def = GetConVarInt(dr_scrambleauto);
	dr_airdash_def = GetConVarInt(dr_airdash);
	dr_push_def = GetConVarInt(dr_push);
}

/* SetupCvars()
**
** Modify several values of the CVars that the plugin needs to work properly.
** -------------------------------------------------------------------------- */
public SetupCvars()
{
	SetConVarInt(dr_queue, 0);
	SetConVarInt(dr_unbalance, 0);
	SetConVarInt(dr_autobalance, 0);
	SetConVarInt(dr_firstblood, 0);
	SetConVarInt(dr_scrambleauto, 0);
	SetConVarInt(dr_airdash, 0);
	SetConVarInt(dr_push, 0);
}

/* ResetCvars()
**
** Reset the values of the CVars that the plugin used to their default values.
** -------------------------------------------------------------------------- */
public ResetCvars()
{
	SetConVarInt(dr_queue, dr_queue_def);
	SetConVarInt(dr_unbalance, dr_unbalance_def);
	SetConVarInt(dr_autobalance, dr_autobalance_def);
	SetConVarInt(dr_firstblood, dr_firstblood_def);
	SetConVarInt(dr_scrambleauto, dr_scrambleauto_def);
	SetConVarInt(dr_airdash, dr_airdash_def);
	SetConVarInt(dr_push, dr_push_def);
	
	//We clear the tries
	ProcessListeners(true);
	ClearTrie(g_RestrictedWeps);
	ClearTrie(g_AllClassWeps);
	ClearTrie(g_CommandToBlock);
	ClearTrie(g_BlockOnlyOnPreparation);
	ClearTrie(g_SndRoundStart);
	ClearTrie(g_SndOnDeath);
	ClearTrie(g_SndOnKill);
	ClearTrie(g_SndLastAlive);
}

/* Command_Block()
**
** Blocks a command
** -------------------------------------------------------------------------- */
public Action:Command_Block(client, const String:command[], argc)
{
	if(g_isDRmap)
		return Plugin_Stop;
	return Plugin_Continue;
}

/* Command_Block_PreparationOnly()
**
** Blocks a command, but only if we are on preparation 
** -------------------------------------------------------------------------- */
public Action:Command_Block_PreparationOnly(client, const String:command[], argc)
{
	if(g_isDRmap && g_onPreparation)
		return Plugin_Stop;
	return Plugin_Continue;
}


/* EmitRandomSound()
**
** Emits a random sound from a trie, it will be emitted for everyone is a client isn't passed.
** -------------------------------------------------------------------------- */
stock EmitRandomSound(Handle:sndTrie,client = -1)
{
	new trieSize = GetTrieSize(sndTrie);
	
	new String:key[4], String:sndFile[PLATFORM_MAX_PATH];
	IntToString(GetRandomInt(1,trieSize),key,sizeof(key));

	if(GetTrieString(sndTrie,key,sndFile,sizeof(sndFile)))
	{
		if(StrEqual(sndFile, ""))
			return;
			
		if(client != -1)
		{
			if(client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
				EmitSoundToClient(client,sndFile,_,_, SNDLEVEL_TRAIN);
			else
				return;
		}
		else	
			EmitSoundToAll(sndFile, _, _, SNDLEVEL_TRAIN);
	}
}

stock GetAlivePlayersCount(team,ignore=-1) 
{ 
	new count = 0, i;

	for( i = 1; i <= MaxClients; i++ ) 
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team && i != ignore) 
			count++; 

	return count; 
}  

stock GetLastPlayer(team,ignore=-1) 
{ 
	for(new i = 1; i <= MaxClients; i++ ) 
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team && i != ignore) 
			return i;
	return -1;
}  