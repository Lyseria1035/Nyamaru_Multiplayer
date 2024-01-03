#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define SIZE_OF_INT			2147483647

#define JOIN_MANUAL			(1 << 0)
#define JOIN_AUTOMATIC		(1 << 1)

#define TEAM_NOTEAM			0
#define TEAM_SPECTATOR		1
#define TEAM_SURVIVOR		2
#define TEAM_INFECTED		3
#define MAX_SLOT			5
#define SOUND_SPECMENU		"ui/helpful_event_1.wav"

Handle
	g_hBotsTimer,
	g_hSDK_NextBotCreatePlayerBot_SurvivorBot,
	g_hSDK_CTerrorPlayer_RoundRespawn,
	g_hSDK_CCSPlayer_State_Transition,
	g_hSDK_SurvivorBot_SetHumanSpectator,
	g_hSDK_CTerrorPlayer_TakeOverBot,
	g_hSDK_CDirector_IsInTransition;

StringMap
	g_smSteamIDs;

ArrayList
	g_aMeleeScripts;

Address
	g_pDirector,
	g_pStatsCondition,
	g_pSavedSurvivorBotsCount;

ConVar
	g_SuicideCommand,
	g_cBotLimit,
	g_cJoinLimit,
	g_cJoinFlags,
	g_cJoinRespawn,
	g_cSpecNotify,
	g_cGiveType,
	g_cGiveTime,
	g_cSurLimit;

int
	g_iSurvivorBot,
	g_iBotLimit,
	g_iJoinLimit,
	g_iJoinFlags,
	g_iJoinRespawn,
	g_iSpecNotify,
	m_hWeaponHandle,
	m_iRestoreAmmo,
	m_restoreWeaponID,
	m_hHiddenWeapon,
	m_isOutOfCheckpoint,
	RestartScenarioTimer;

bool
	g_bLateLoad,
	g_bGiveType,
	g_bGiveTime,
	g_bInSpawnTime,
	g_bRoundStart,
	g_bShouldFixAFK,
	g_bShouldIgnore,
	g_bBlockUserMsg;

enum struct Weapon {
	ConVar Flags;

	int Count;
	int Allowed[20];
}

Weapon
	g_eWeapon[MAX_SLOT];

enum struct Player {
	int Bot;
	int Player;

	bool Notify;

	char Model[128];
	char AuthId[32];
}

Player
	g_ePlayer[MAXPLAYERS + 1];

static const char
	g_sSurvivorNames[][] = {
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis"
	},
	g_sSurvivorModels[][] = {
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	},
	g_sWeaponName[MAX_SLOT][][] = {
		{
			"weapon_smg",
			"weapon_smg_mp5",
			"weapon_smg_silenced",
			"weapon_pumpshotgun",
			"weapon_shotgun_chrome",
			"weapon_rifle",
			"weapon_rifle_desert",
			"weapon_rifle_ak47",
			"weapon_rifle_sg552",
			"weapon_autoshotgun",
			"weapon_shotgun_spas",
			"weapon_hunting_rifle",
			"weapon_sniper_military",
			"weapon_sniper_scout",
			"weapon_sniper_awp",
			"weapon_rifle_m60",
			"weapon_grenade_launcher"
		},
		{
			"weapon_pistol",
			"weapon_pistol_magnum",
			"weapon_chainsaw",
			"fireaxe",
			"frying_pan",
			"machete",
			"baseball_bat",
			"crowbar",
			"cricket_bat",
			"tonfa",
			"katana",
			"electric_guitar",
			"knife",
			"golfclub",
			"shovel",
			"pitchfork",
			"riotshield",
		},
		{
			"weapon_molotov",
			"weapon_pipe_bomb",
			"weapon_vomitjar",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{
			"weapon_first_aid_kit",
			"weapon_defibrillator",
			"weapon_upgradepack_incendiary",
			"weapon_upgradepack_explosive",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{
			"weapon_pain_pills",
			"weapon_adrenaline",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		}
	},
	g_sWeaponModels[][] = {
		"models/w_models/weapons/w_smg_uzi.mdl",
		"models/w_models/weapons/w_smg_mp5.mdl",
		"models/w_models/weapons/w_smg_a.mdl",
		"models/w_models/weapons/w_pumpshotgun_A.mdl",
		"models/w_models/weapons/w_shotgun.mdl",
		"models/w_models/weapons/w_rifle_m16a2.mdl",
		"models/w_models/weapons/w_desert_rifle.mdl",
		"models/w_models/weapons/w_rifle_ak47.mdl",
		"models/w_models/weapons/w_rifle_sg552.mdl",
		"models/w_models/weapons/w_autoshot_m4super.mdl",
		"models/w_models/weapons/w_shotgun_spas.mdl",
		"models/w_models/weapons/w_sniper_mini14.mdl",
		"models/w_models/weapons/w_sniper_military.mdl",
		"models/w_models/weapons/w_sniper_scout.mdl",
		"models/w_models/weapons/w_sniper_awp.mdl",
		"models/w_models/weapons/w_m60.mdl",
		"models/w_models/weapons/w_grenade_launcher.mdl",

		"models/w_models/weapons/w_pistol_a.mdl",
		"models/w_models/weapons/w_desert_eagle.mdl",
		"models/weapons/melee/w_chainsaw.mdl",
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl",

		"models/w_models/weapons/w_eq_molotov.mdl",
		"models/w_models/weapons/w_eq_pipebomb.mdl",
		"models/w_models/weapons/w_eq_bile_flask.mdl",

		"models/w_models/weapons/w_eq_medkit.mdl",
		"models/w_models/weapons/w_eq_defibrillator.mdl",
		"models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
		"models/w_models/weapons/w_eq_explosive_ammopack.mdl",

		"models/w_models/weapons/w_eq_adrenaline.mdl",
		"models/w_models/weapons/w_eq_painpills.mdl"
	};

public Plugin myinfo = 
{
	name = "System Auto Players", 
	author = "Kuroneko15", 
	description = "All in 1", 
	version = "1.0", 
	url = "N/A"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

#define CVAR_FLAGS	FCVAR_NOTIFY
public void OnPluginStart()
{
	InitData();
	g_smSteamIDs = new StringMap();
	g_aMeleeScripts = new ArrayList(ByteCountToCells(64));

	AddCommandListener(Listener_spec_next, "spec_next");
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);

	g_cBotLimit =				CreateConVar("sap_start_limit",				"4",		"How many survivor spawn when map start?", CVAR_FLAGS, true, 1.0, true, float(MaxClients));
	g_cJoinLimit =				CreateConVar("sap_join_limit",			"-1",		"If players join reaches this number, bots will not spawn to keep slots for your friend.", CVAR_FLAGS, true, -1.0, true, float(MaxClients));
	g_cJoinFlags =				CreateConVar("sap_join_show",			"3",		"When the player has finished downloading data and ready to join\n0 = Plugin not process, 1 = Spectator waiting to Enter [!join] in chat, 2 = Automatically join survivor, 3 = IDLE waiting.", CVAR_FLAGS);
	g_cJoinRespawn =			CreateConVar("sap_join_respawn",		"1",		"Setting for player for exit and re-entering?. \n0 = Dead State, 1 = Survivor Respawn, -1 = Spawn and takevoer new Bot.", CVAR_FLAGS);
	g_cSpecNotify =				CreateConVar("sap_spec_notify",		"0",		"Message notify guide how to join survivor?\n0 = Disable, 1 = Chatbar, 2 = Hintbox, 3 = Menu choose team pop-up.", CVAR_FLAGS);
	g_eWeapon[0].Flags =		CreateConVar("sap_give_slot0",			"31",	"First slot weapon for players \n0=Nothing, 1=Uzi, 4=Smg Silent, 8=PumpShotgun, 16=ChromeShotgun, 32=Rifle, 2048=Hunting Rifle, 98304=Tier0, 31=Tier1, 32736=Tier2, 131071=Random.", CVAR_FLAGS);
	g_eWeapon[1].Flags =		CreateConVar("sap_give_slot1",			"64",		"Second slot weapon for players. \n0=Nothing,1=Dual Pistol, 2=Magnum, 8=Fireaxe, 32=Machete, 1024=Katana, 256=Cricket, 64=Baseball, 131071=Random ALl.", CVAR_FLAGS);
	g_eWeapon[2].Flags =		CreateConVar("sap_give_slot2",			"0",		"Third slot item for players. \n0=Nothing, 1=Moltov, 2=Pipe Bomb, 4=Vomitjar, 7=Random.", CVAR_FLAGS);
	g_eWeapon[3].Flags =		CreateConVar("sap_give_slot3",			"0",		"Fourth slot item for players. \n0=Nothing, 1=Medkit, 2=Defib, 4=Incendiary Pack, 8=Explosive Pack, 15=Random.", CVAR_FLAGS);
	g_eWeapon[4].Flags =		CreateConVar("sap_give_slot4",			"0",		"Fifth slot item for players. \n0=Nothing, 1= Pain Pills, 2=Adrenaline, 3=Random.", CVAR_FLAGS);
	g_cGiveType =				CreateConVar("sap_give_type",			"1",		"Equipment for players? \n0 = Another plugin, 1 = Use your custom setting, 2 = Automatically calculate average equipment quality (gacha all give option).", CVAR_FLAGS);
	g_cGiveTime =				CreateConVar("sap_give_time",			"1",		"When the equipment function work for players?. \n0 = All survivor after first map start, 1 = Only work when 5+ players join.", CVAR_FLAGS);

	g_cSurLimit = FindConVar("survivor_limit");
	g_cSurLimit.Flags &= ~FCVAR_NOTIFY;
	g_cSurLimit.SetBounds(ConVarBound_Upper, true, float(MaxClients));

	g_cBotLimit.AddChangeHook(CvarChanged_Limit);
	g_cSurLimit.AddChangeHook(CvarChanged_Limit);

	g_cJoinLimit.AddChangeHook(CvarChanged_General);
	g_cJoinFlags.AddChangeHook(CvarChanged_General);
	g_cJoinRespawn.AddChangeHook(CvarChanged_General);
	g_cSpecNotify.AddChangeHook(CvarChanged_General);

	g_eWeapon[0].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[1].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[2].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[3].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[4].Flags.AddChangeHook(CvarChanged_Weapon);

	g_cGiveType.AddChangeHook(CvarChanged_Weapon);
	g_cGiveTime.AddChangeHook(CvarChanged_Weapon);

	AutoExecConfig(true, "system_auto_players");
	
	RegConsoleCmd("sm_info", 					cmdServerInfo, "Display Your Server Info");
	RegConsoleCmd("sm_ping", 					cmdPing, "Display All Players Ping To Chat");
	
	RegConsoleCmd("sm_afk",						cmdGoIdle,		"AFK command");
	RegConsoleCmd("sm_teams",					cmdTeamPanel,	"TeamPanel");
	RegConsoleCmd("sm_join",					cmdJoinTeam2,	"Join the game");
	RegConsoleCmd("sm_takebot",					cmdTakeOverBot,	"Takeover Bot");
	RegConsoleCmd("sm_kill", 					cmdKillClient, 	"Kill your self only work when incap");
	
	RegAdminCmd("sm_spec",						cmdJoinTeam1,	ADMFLAG_ROOT,	"Join Spectator");
	RegAdminCmd("sm_bot",						cmdBotSet,		ADMFLAG_ROOT,	"Set Bot for players");

	HookEvent("round_end",						Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",					Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",					Event_PlayerSpawn);
	HookEvent("player_death",					Event_PlayerDeath,	EventHookMode_Pre);
	HookEvent("player_team",					Event_PlayerTeam);
	HookEvent("player_bot_replace",				Event_PlayerBotReplace);
	HookEvent("bot_player_replace",				Event_BotPlayerReplace);
	HookEvent("finale_vehicle_leaving",			Event_FinaleVehicleLeaving);
	
	HookEvent("player_incapacitated_start",Event_PlayerIncapacitatedStart);
	HookEvent("player_ledge_grab",Event_PlayerLedgeGrab);
	UnhookEvent("player_ledge_grab", 			Event_PlayerLedgeGrab);
	UnhookEvent("player_incapacitated_start",	Event_PlayerIncapacitatedStart);

	if (g_bLateLoad)
		g_bRoundStart = !OnEndScenario();
}

public void OnPluginEnd()
{
	StatsConditionPatch(false);
}

Action cmdGoIdle(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart)
	{
		ReplyToCommand(client, "\x05The game has not started yet.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return Plugin_Handled;

	GoAFKTimer(client, 0.5);
	return Plugin_Handled;
}

void GoAFKTimer(int client, float flDuration)
{
	static int m_GoAFKTimer = -1;
	if (m_GoAFKTimer == -1)
		m_GoAFKTimer = FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") - 12;

	SetEntDataFloat(client, m_GoAFKTimer + 4, flDuration);
	SetEntDataFloat(client, m_GoAFKTimer + 8, GetGameTime() + flDuration);
}

Action cmdTeamPanel(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	DrawTeamPanel(client, false);
	return Plugin_Handled;
}

Action cmdJoinTeam2(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		PrintToChat(client, "\x05The game has not started yet.");
		return Plugin_Handled;
	}

	if (!(g_iJoinFlags & JOIN_MANUAL))
	{
		PrintToChat(client, "\x04Custom join has been disable.");
		return Plugin_Handled;
	}

	if (CheckJoinLimit())
	{
		PrintToChat(client, "\x05The admin set survivors has reached limit:\x04%d\x01.", g_iJoinLimit);
		return Plugin_Handled;
	}

	switch (GetClientTeam(client))
	{
		case TEAM_SPECTATOR:
		{
			if (GetBotOfIdlePlayer(client))
				return Plugin_Handled;
		}

		case TEAM_SURVIVOR:
		{
			PrintToChat(client, "\x05You are currently in the survivor team.");
			return Plugin_Handled;
		}

		default:
			ChangeClientTeam(client, TEAM_SPECTATOR);
	}

	JoinSurTeam(client);
	return Plugin_Handled;
}

bool JoinSurTeam(int client)
{
	int bot = GetClientOfUserId(g_ePlayer[client].Bot);
	bool canRespawn = g_iJoinRespawn == -1 || (g_iJoinRespawn && IsFirstTime(client));
	if (!bot || !IsValidSurBot(bot))
		bot = FindUselessSurBot(canRespawn);

	if (!bot && !canRespawn)
	{
		ChangeClientTeam(client, TEAM_SURVIVOR);
		if (IsPlayerAlive(client))
			State_Transition(client, 6);

		PrintToChat(client, "\x05Re-entering data confirm \x04Death state\x01.");
		return true;
	}

	bool canTake;
	if (!canRespawn)
	{
		if (IsPlayerAlive(bot))
		{
			canTake = CheckForTake(bot, bot);
			SetHumanSpec(bot, client);
			if (canTake)
			{
				TakeOverBot(client);
				SetInvulnerable(client, 1.5);
			}
			else
			{
				SetInvulnerable(bot, 1.5);
				WriteTakeoverPanel(client, bot);
			}
		}
		else
		{
			SetHumanSpec(bot, client);
			TakeOverBot(client);
			PrintToChat(client, "\x05Re-entering data confirm \x04Death state\x01.");
		}
	}
	else
	{
		bool addBot = !bot;
		if (addBot && (bot = SpawnSurBot()) == -1)
			return false;

		if (!IsPlayerAlive(bot))
		{
			RespawnPlayer(bot);
			canTake = CheckForTake(bot, TeleportPlayer(bot));
		}
		else
			canTake = CheckForTake(bot, addBot ? TeleportPlayer(bot) : bot);

		SetHumanSpec(bot, client);
		if (canTake)
		{
			TakeOverBot(client);
			SetInvulnerable(client, 1.5);
		}
		else
		{
			SetInvulnerable(bot, 1.5);
			WriteTakeoverPanel(client, bot);
		}
	}
	return true;
}

Action cmdTakeOverBot(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		ReplyToCommand(client, "The game has not started yet.");
		return Plugin_Handled;
	}

	if (!IsTeamAllowed(client))
	{
		PrintToChat(client, "Not allow to takeover.");
		return Plugin_Handled;
	}

	if (CheckJoinLimit())
	{
		PrintToChat(client, "\x05The number of survivors teams has been reached \x04%d\x01.", g_iJoinLimit);
		return Plugin_Handled;
	}

	if (!FindUselessSurBot(true))
	{
		PrintToChat(client, "\x05The Bot \x04not ready \x05to take over\x01.");
		return Plugin_Handled;
	}

	TakeOverBotMenu(client);
	return Plugin_Handled;
}

int IsTeamAllowed(int client)
{
	int team = GetClientTeam(client);
	switch (team)
	{
		case TEAM_SPECTATOR:
		{
			if (GetBotOfIdlePlayer(client))
				team = 0;
		}

		case TEAM_SURVIVOR:
		{
			if (IsPlayerAlive(client))
				team = 0;
		}
	}
	return team;
}

void TakeOverBotMenu(int client)
{
	char info[12];
	char disp[64];
	Menu menu = new Menu(TakeOverBot_MenuHandler);
	menu.SetTitle("- Please select a takeover target");
	menu.AddItem("o", "Current spectator target");

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidSurBot(i))
			continue;

		FormatEx(info, sizeof info, "%d", GetClientUserId(i));
		FormatEx(disp, sizeof disp, "%s - %s", IsPlayerAlive(i) ? "Ready" : "Dead", g_sSurvivorNames[GetCharacter(i)]);
		menu.AddItem(info, disp);
	}

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

Action cmdServerInfo(int client, int args)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		DisplayStatus(client);

		char sBuffer[64];
		FormatEx(sBuffer, sizeof(sBuffer), "\x04Ping: \x03 %.3f ms", GetClientAvgLatency(client, NetFlow_Both));
		ReplaceString(sBuffer, sizeof(sBuffer), "0.00", "", false);
		ReplaceString(sBuffer, sizeof(sBuffer), "0.0", "", false);
		ReplaceString(sBuffer, sizeof(sBuffer), "0.", "", false);
		ReplyToCommand(client, sBuffer);
	}
	return Plugin_Handled;
}

Action cmdPing(int client, int args)
{
	ReplyToCommand(client, "\x03Players Ping Status:");
	{
		for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i)) 
		{
			char sBuffer[64];
			FormatEx(sBuffer, sizeof(sBuffer), "%.3f ms", GetClientAvgLatency(i, NetFlow_Both));
			ReplaceString(sBuffer, sizeof(sBuffer), "0.00", "", false);
			ReplaceString(sBuffer, sizeof(sBuffer), "0.0", "", false);
			ReplaceString(sBuffer, sizeof(sBuffer), "0.", "", false);
			ReplyToCommand(client, "\x03► \x04%N ♦ \x05%s", i, sBuffer);	
		}
	}
	return Plugin_Handled;
}

int TakeOverBot_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action)
	{
		case MenuAction_Select:
		{
			if (CheckJoinLimit())
			{
				PrintToChat(param1, "\x05The number of survivors limit has been reached \x04%d\x01.", g_iJoinLimit);
				return 0;
			}

			int bot;
			char item[12];
			menu.GetItem(param2, item, sizeof item);
			if (item[0] == 'o')
			{
				bot = GetEntPropEnt(param1, Prop_Send, "m_hObserverTarget");
				if (bot > 0 && bot <= MaxClients && IsValidSurBot(bot))
				{
					SetHumanSpec(bot, param1);
					TakeOverBot(param1);
				}
				else
					PrintToChat(param1, "\x05The target you choose not ready.");
			}
			else {
				bot = GetClientOfUserId(StringToInt(item));
				if (!bot || !IsValidSurBot(bot))
					PrintToChat(param1, "\x05The selected target BOT has expired");
				else {
					int team = IsTeamAllowed(param1);
					if (!team)
						PrintToChat(param1, "\x05Not eligible for takeover.");
					else {
						if (team != TEAM_SPECTATOR)
							ChangeClientTeam(param1, TEAM_SPECTATOR);

						SetHumanSpec(bot, param1);
						TakeOverBot(param1);
					}
				}
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdJoinTeam1(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		ReplyToCommand(client, "The game has not started yet.");
		return Plugin_Handled;
	}

	bool idle = !!GetBotOfIdlePlayer(client);
	if (!idle && GetClientTeam(client) == TEAM_SPECTATOR) {
		PrintToChat(client, "You are currently in the spectator team.");
		return Plugin_Handled;
	}

	if (idle)
		TakeOverBot(client);

	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Handled;
}

Action cmdBotSet(int client, int args)
{
	if (!g_bRoundStart)
	{
		ReplyToCommand(client, "The game has not started. Please check again.");
		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "\x04!bot/sm_bot <\x05value\x01>.");
		return Plugin_Handled;
	}

	int arg = GetCmdArgInt(1);
	if (arg < 1 || arg > MaxClients - 1)
	{
		ReplyToCommand(client, "\x03Value range \x051\x01 ~ \x05%d\x01.", MaxClients - 1);
		return Plugin_Handled;
	}

	delete g_hBotsTimer;
	g_cBotLimit.IntValue = arg;
	g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);
	ReplyToCommand(client, "\x05The number of bot spawn in start map set to \x04%d\x01.", arg);
	return Plugin_Handled;
}

Action cmdKillClient(int client, int args)
{ 
	if (GetConVarBool(g_SuicideCommand))
	{
		bool incapacitated = GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1;
		if (incapacitated)
		{
			SDKHooks_TakeDamage(client, client, client, 100000.0);
		}
		if (!incapacitated)
		{
			//PrintHintText(client, "Only available while incapacitated or ledge hanging");
			PrintToChat(client, "\x04[Kill] \x05lệnh chỉ có hiệu lực khi bạn bị \x03gục ngã hoặc treo bám.");
		}
	}
	return Plugin_Handled; 
} 

Action Listener_spec_next(int client, char[] command, int argc)
{
	if (!g_bRoundStart)
		return Plugin_Continue;

	if (!(g_iJoinFlags & JOIN_MANUAL) || !g_ePlayer[client].Notify)
		return Plugin_Continue;

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (GetClientTeam(client) != TEAM_SPECTATOR || GetBotOfIdlePlayer(client))
		return Plugin_Continue;

	if (CheckJoinLimit())
		return Plugin_Continue;

	if (PrepRestoreBots())
		return Plugin_Continue;

	g_ePlayer[client].Notify = false;

	switch (g_iSpecNotify)
	{
		case 1:
			PrintToChat(client, "\x05[\x04>>>\x05] \x03Enter \x04!join \x03 in chat if you are ready.");

		case 2:
			PrintHintText(client, ">> Enter !join in chat if you are ready <<");

		case 3:
			JoinTeam2Menu(client);
	}

	return Plugin_Continue;
}

void JoinTeam2Menu(int client)
{
	EmitSoundToClient(client, SOUND_SPECMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	Menu menu = new Menu(JoinTeam2_MenuHandler);
	menu.SetTitle("Join the survivors?");
	menu.AddItem("y", "Yes, join the game.");
	menu.AddItem("n", "No, choose again.");

	if (FindUselessSurBot(true))
		menu.AddItem("t", "Take over the designated BOT");

	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int JoinTeam2_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
					cmdJoinTeam2(param1, 0);

				case 2:
				{
					if (FindUselessSurBot(true))
						TakeOverBotMenu(param1);
					else
						PrintToChat(param1, "\x05No Bot ready to takeover\x01.");
				}
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action Event_PlayerIncapacitatedStart(Handle event, const char[] message, bool dontBroadcast)
{
	if (GetConVarBool(g_SuicideCommand))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!IsFakeClient(client))
		{
			PrintHintText(client, "Nhập !kill để kết liễu bản thân ngay lập tức");
			PrintToChat(client, "\x04[Tự sát] \x05Nhập \x04!kill\x05 vào đây \x03để kết liễu bản thân và bắt đầu đếm ngược.");
		}
	}
	return Plugin_Continue;
}

Action Event_PlayerLedgeGrab(Handle event, const char[] message, bool dontBroadcast)
{
	if (GetConVarBool(g_SuicideCommand))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!IsFakeClient(client))
		{
			PrintHintText(client, "Nhập !kill để kết liễu bản thân ngay lập tức");
			PrintToChat(client, "\x04[Tự sát] \x05Nhập \x04!kill\x05 vào đây \x03để kết liễu bản thân và bắt đầu đếm ngược.");
		}
	}
	return Plugin_Continue;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bBlockUserMsg)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char buffer[254];
	msg.ReadString(buffer, sizeof buffer, true);
	if (strcmp(buffer, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	static bool once;
	if (!once)
	{
		once = true;
		GeCvars_Limit();
	}

	GeCvars_Weapon();
	GeCvars_General();
}

void CvarChanged_Limit(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_Limit();
}

void GeCvars_Limit()
{
	g_iBotLimit = g_cSurLimit.IntValue = g_cBotLimit.IntValue;
}

void CvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_General();
}

void GeCvars_General()
{
	g_iJoinLimit =		g_cJoinLimit.IntValue;
	g_iJoinFlags =		g_cJoinFlags.IntValue;
	g_iJoinRespawn =	g_cJoinRespawn.IntValue;
	g_iSpecNotify =		g_cSpecNotify.IntValue;
}

void CvarChanged_Weapon(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GeCvars_Weapon();
}

void GeCvars_Weapon()
{
	int num;
	for (int i; i < MAX_SLOT; i++)
	{
		g_eWeapon[i].Count = 0;
		if (!g_eWeapon[i].Flags.BoolValue || IsNullSlot(i))
			num++;
	}

	g_bGiveType = num < MAX_SLOT ? g_cGiveType.BoolValue : false;
	g_bGiveTime = g_cGiveTime.BoolValue;
}

bool IsNullSlot(int slot)
{
	int flags = g_eWeapon[slot].Flags.IntValue;
	for (int i; i < sizeof g_sWeaponName[]; i++)
	{
		if (!g_sWeaponName[slot][i][0])
			break;

		if ((1 << i) & flags)
			g_eWeapon[slot].Allowed[g_eWeapon[slot].Count++] = i;
	}
	return !g_eWeapon[slot].Count;
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;

	g_ePlayer[client].AuthId[0] = '\0';

	if (g_bRoundStart)
	{
		delete g_hBotsTimer;
		g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);
	}
}

Action tmrBotsUpdate(Handle timer)
{
	g_hBotsTimer = null;

	if (!PrepRestoreBots())
		SpawnCheck();
	else
		g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);

	return Plugin_Continue;
}

void SpawnCheck()
{
	if (!g_bRoundStart)
		return;

	int iSurvivor		= GetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor	= GetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit	= g_iBotLimit;
	int iSurvivorMax	= iHumanSurvivor > iSurvivorLimit ? iHumanSurvivor : iSurvivorLimit;

	if (iSurvivor > iSurvivorMax)
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if (iSurvivor < iSurvivorLimit)
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLimit - iSurvivor);

	for (; iSurvivorMax < iSurvivor; iSurvivorMax++)
		KickUnusedSurBot();

	for (; iSurvivor < iSurvivorLimit; iSurvivor++)
		SpawnExtraSurBot();
}

void DisplayStatus(int client)
{
	int g_iClientInServer;
	
	int g_iHostIp;
	
	int maxplayers = GetMaxPlayers();
	
	char g_sHostName[512];
	char g_sServerIpHost[32];
	char g_sServerPort[128];
	char g_sCurrentMap[256];
	char g_ServerTime[64];
	char g_sNextmap[256];
	
	Handle g_hHostIp;
	Handle g_hHostPort;
	Handle g_hHostName;
	Handle g_hNextMap;
	
	g_hHostIp = FindConVar("hostip");
	g_hHostPort = FindConVar("hostport");
	g_iHostIp = GetConVarInt(g_hHostIp);

	GetConVarString(g_hHostPort, g_sServerPort, sizeof(g_sServerPort));
	FormatEx(g_sServerIpHost, sizeof(g_sServerIpHost), "%u.%u.%u.%u:%s", g_iHostIp >> 24 & 255, g_iHostIp >> 16 & 255, g_iHostIp >> 8 & 255, g_iHostIp & 255, g_sServerPort);
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	
	g_hNextMap = FindConVar("sm_nextmap");
	GetConVarString(g_hNextMap, g_sNextmap, sizeof(g_sNextmap));
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			g_iClientInServer++;
		}
	}
	g_hHostName = FindConVar("hostname");
	GetConVarString(g_hHostName, g_sHostName, sizeof(g_sHostName));
	FormatTime(g_ServerTime, sizeof(g_ServerTime), NULL_STRING, -1);
	
	PrintToChat(client, "\x04Chủ host : \x03%s", g_sHostName);
	
	PrintToChat(client, "\x04Ip Máy chủ  : \x03%s", g_sServerIpHost);
	
	PrintToChat(client, "\x04Tên Bản Đồ : \x03%s", g_sCurrentMap);

	if (!StrEqual(g_sNextmap, "", false))
	{
		PrintToChat(client, "next map: %s", g_sNextmap);
	}
	
	PrintToChat(client, "\x04Số lượng :\x03 %d/%d người", g_iClientInServer, maxplayers);
	
	PrintToChat(client, "\x04Thời Gian :\x03 %s\n", g_ServerTime);
}

void KickUnusedSurBot()
{
	int bot = FindUnusedSurBot();
	if (bot)
	{
		RemoveAllWeapons(bot);
		KickClient(bot, "\x05 Remove Useless Client Bot.");
	}
}

void SpawnExtraSurBot()
{
	int bot = SpawnSurBot();
	if (bot != -1) {
		if (!IsPlayerAlive(bot))
			RespawnPlayer(bot);

		TeleportPlayer(bot);
		SetInvulnerable(bot, 1.5);
	}
}

public void OnMapEnd()
{
	ResetPlugin();
}

void ResetPlugin()
{
	delete g_hBotsTimer;
	g_smSteamIDs.Clear();
	g_bRoundStart = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();

	int player;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		player = GetIdlePlayerOfBot(i);
		if (player && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == TEAM_SPECTATOR) {
			SetHumanSpec(i, player);
			TakeOverBot(player);
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStart = true;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	delete g_hBotsTimer;
	g_hBotsTimer = CreateTimer(2.0, tmrBotsUpdate);

	SetEntProp(client, Prop_Send, "m_isGhost", 0);
	if (!IsFakeClient(client) && IsFirstTime(client))
		RecordSteamID(client);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	int player = GetIdlePlayerOfBot(client);
	if (player && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == TEAM_SPECTATOR) {
		SetHumanSpec(client, player);
		TakeOverBot(player);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	switch (event.GetInt("team"))
	{
		case TEAM_SPECTATOR:
		{
			g_ePlayer[client].Notify = true;

			if (g_iJoinFlags & JOIN_AUTOMATIC && event.GetInt("oldteam") == TEAM_NOTEAM)
				CreateTimer(1.0, tmrJoinTeam2, event.GetInt("userid"), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		case TEAM_SURVIVOR:
			SetEntProp(client, Prop_Send, "m_isGhost", 0);
	}
}

Action tmrJoinTeam2(Handle timer, int client)
{
	if (!(g_iJoinFlags & JOIN_AUTOMATIC))
		return Plugin_Stop;

	client = GetClientOfUserId(client);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (GetClientTeam(client) > TEAM_SPECTATOR || GetBotOfIdlePlayer(client))
		return Plugin_Stop;

	if (CheckJoinLimit())
		return Plugin_Stop;

	if (!g_bRoundStart || PrepRestoreBots() || GetClientTeam(client) <= TEAM_NOTEAM)
		return Plugin_Continue;

	JoinSurTeam(client);
	return Plugin_Stop;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	int playerId = event.GetInt("player");
	int player = GetClientOfUserId(playerId);
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int botId = event.GetInt("bot");
	int bot = GetClientOfUserId(botId);

	g_ePlayer[bot].Player = playerId;
	g_ePlayer[player].Bot = botId;

	if (!g_ePlayer[player].Model[0])
		return;

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_ePlayer[player].Model);
	for (int i; i < sizeof g_sSurvivorModels; i++)
	{
		if (strcmp(g_ePlayer[player].Model, g_sSurvivorModels[i], false) == 0)
		{
			g_bBlockUserMsg = true;
			SetClientInfo(bot, "name", g_sSurvivorNames[i]);
			g_bBlockUserMsg = false;
			break;
		}
	}
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));

	char model[128];
	GetClientModel(bot, model, sizeof model);
	SetEntityModel(player, model);
}

void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast) {
	int iEnt = -1;
	int loop = MaxClients + 1;
	while ((loop = FindEntityByClassname(loop, "info_survivor_position")) != -1) {
		if (iEnt == -1)
			iEnt = loop;

		if (1 <= GetEntProp(loop, Prop_Send, "m_order") <= 4) {
			iEnt = loop;
			break;
		}
	}

	if (iEnt != -1) {
		float vPos[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);

		loop = -1;
		static const char Order[][] = {"1", "2", "3", "4"};
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
				continue;

			if (++loop < 4)
				continue;

			iEnt = CreateEntityByName("info_survivor_position");
			if (iEnt != -1) {
				DispatchKeyValue(iEnt, "Order", Order[loop % 4]);
				TeleportEntity(iEnt, vPos);
				DispatchSpawn(iEnt);
			}
		}
	}
}

bool IsFirstTime(int client) {
	if (!CacheSteamID(client))
		return false;

	bool allow = true;
	g_smSteamIDs.GetValue(g_ePlayer[client].AuthId, allow);
	return allow;
}

void RecordSteamID(int client) {
	if (CacheSteamID(client))
		g_smSteamIDs.SetValue(g_ePlayer[client].AuthId, false, true);
}

bool CacheSteamID(int client) {
	if (g_ePlayer[client].AuthId[0])
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_ePlayer[client].AuthId, sizeof Player::AuthId))
		return true;

	g_ePlayer[client].AuthId[0] = '\0';
	return false;
}

int GetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetMaxPlayers()
{
	ConVar hndl = FindConVar("sv_maxplayers");
	if (hndl)
	{
		int maxplayers = hndl.IntValue;
		return maxplayers != -1 ? maxplayers : GetModePlayers();
	}
	return GetModePlayers();
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

int GetTeamPlayers(int team, bool includeBots) {
	int num;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != team)
			continue;

		if (!includeBots && IsFakeClient(i) && !GetIdlePlayerOfBot(i))
			continue;

		num++;
	}
	return num;
}

bool CheckJoinLimit() {
	if (g_iJoinLimit == -1)
		return false;

	int num;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && (!IsFakeClient(i) || GetIdlePlayerOfBot(i)))
			num++;
	}

	return num >= g_iJoinLimit;
}

int FindUnusedSurBot() {
	int client = MaxClients;
	ArrayList aClients = new ArrayList(2);

	for (; client >= 1; client--) {
		if (!IsValidSurBot(client))
			continue;

		aClients.Set(aClients.Push(IsSpecInvalid(GetClientOfUserId(g_ePlayer[client].Player)) ? 0 : 1), client, 1);
	}

	if (!aClients.Length)
		client = 0;
	else {
		aClients.Sort(Sort_Ascending, Sort_Integer);
		client = aClients.Get(0, 1);
	}

	delete aClients;
	return client;
}

int FindUselessSurBot(bool alive) {
	int client;
	ArrayList aClients = new ArrayList(2);

	for (int i = MaxClients; i >= 1; i--) {
		if (!IsValidSurBot(i))
			continue;

		client = GetClientOfUserId(g_ePlayer[i].Player);
		aClients.Set(aClients.Push(IsPlayerAlive(i) == alive ? (IsSpecInvalid(client) ? 0 : 1) : (IsSpecInvalid(client) ? 2 : 3)), i, 1);
	}

	if (!aClients.Length)
		client = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		client = aClients.Length - 1;
		client = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(client, 0)), client), 1);
	}

	delete aClients;
	return client;
}

bool IsValidSurBot(int client) {
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !GetIdlePlayerOfBot(client);
}

bool IsSpecInvalid(int client) {
	return !client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR;
}

int GetModePlayers()
{
	return LoadFromAddress(L4D_GetPointer(POINTER_SERVER) + view_as<Address>(L4D_GetServerOS() ? 380 : 384), NumberType_Int32);
}

int TeleportPlayer(int client)
{
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++)
	{
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != TEAM_SURVIVOR || !IsPlayerAlive(target))
			continue;

		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else
	{
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target)
	{
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos);
		return target;
	}

	return client;
}

void SetInvulnerable(int client, float flDuration)
{
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, flDuration);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, GetGameTime() + flDuration);
}

// 给玩家近战
// L4D2- Melee In The Saferoom (https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484)
public void OnMapStart()
{
	GetMeleeStringTable();
	PrecacheSound(SOUND_SPECMENU);

	int i;
	for (; i < sizeof g_sWeaponModels; i++)
		PrecacheModel(g_sWeaponModels[i], true);

	char buffer[64];
	for (i = 3; i < sizeof g_sWeaponName[]; i++) {
		FormatEx(buffer, sizeof buffer, "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		PrecacheGeneric(buffer, true);
	}
}

void GetMeleeStringTable() {
	g_aMeleeScripts.Clear();
	int table = FindStringTable("meleeweapons");
	if (table != INVALID_STRING_TABLE) {
		int num = GetStringTableNumStrings(table);
		char str[64];
		for (int i; i < num; i++) {
			ReadStringTable(table, i, str, sizeof str);
			g_aMeleeScripts.PushString(str);
		}
	}
}

void GiveMelee(int client, const char[] meleeName) {
	char buffer[64];
	if (g_aMeleeScripts.FindString(meleeName) != -1)
		strcopy(buffer, sizeof buffer, meleeName);
	else {
		int num = g_aMeleeScripts.Length;
		if (num)
			g_aMeleeScripts.GetString(Math_GetRandomInt(0, num - 1), buffer, sizeof buffer);
	}

	GivePlayerItem(client, buffer);
}

enum struct Zombie {
	int idx;
	int class;
	int client;
}

Handle g_hPanelTimer[MAXPLAYERS + 1];
void DrawTeamPanel(int client, bool autoRefresh)
{
	static const char ZombieName[][] = {
		"Smoker",
		"Boomer",
		"Hunter",
		"Spitter",
		"Jockey",
		"Charger",
		"Witch",
		"Tank",
		"None"
	};

	Panel panel = new Panel();
	panel.SetTitle("**** Players Data Panel *****");

	static char info[MAX_NAME_LENGTH];
	static char name[MAX_NAME_LENGTH];

	FormatEx(info, sizeof info, "Spectator [%d]", GetTeamPlayers(TEAM_SPECTATOR, false));
	panel.DrawItem(info);

	int i = 1;
	for (; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SPECTATOR)
			continue;

		GetClientName(i, name, sizeof name);
		FormatEx(info, sizeof info, "%s - %s", GetBotOfIdlePlayer(i) ? "IDLE" : "Spec", name);
		panel.DrawText(info);
	}

	FormatEx(info, sizeof info, "Survivors [%d/%d] - %d Bots", GetTeamPlayers(TEAM_SURVIVOR, false), g_iBotLimit, GetSurBotsCount());
	panel.DrawItem(info);

	static ConVar cv;
	if (!cv)
		cv = FindConVar("survivor_max_incapacitated_count");

	int maxInc = cv.IntValue;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		GetClientName(i, name, sizeof name);

		if (!IsPlayerAlive(i))
			FormatEx(info, sizeof info, "Dead - %s", name);
		else {
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated"))
				FormatEx(info, sizeof info, "Down - %dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
			else if (GetEntProp(i, Prop_Send, "m_currentReviveCount") >= maxInc)
				FormatEx(info, sizeof info, "Blind - %dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
			else
				FormatEx(info, sizeof info, "%dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);

		}

		panel.DrawText(info);
	}

	FormatEx(info, sizeof info, "Infected [%d]", GetTeamPlayers(TEAM_INFECTED, false));
	panel.DrawItem(info);

	Zombie zombie;
	ArrayList aClients = new ArrayList(sizeof Zombie);
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED)
			continue;

		zombie.class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (zombie.class != 8 && IsFakeClient(i))
			continue;

		zombie.client = i;
		zombie.idx = zombie.class == 8 ? (!IsFakeClient(i) ? 0 : 1) : 2;
		aClients.PushArray(zombie);
	}

	int num = aClients.Length;
	if (num) {
		aClients.Sort(Sort_Ascending, Sort_Integer);
		for (i = 0; i < num; i++) {
			aClients.GetArray(i, zombie);
			GetClientName(zombie.client, name, sizeof name);

			if (IsPlayerAlive(zombie.client)) {
				if (GetEntProp(zombie.client, Prop_Send, "m_isGhost"))
					FormatEx(info, sizeof info, "(%s)Ghost - %s", ZombieName[zombie.class - 1], name);
				else
					FormatEx(info, sizeof info, "(%s)%dHP - %s", ZombieName[zombie.class - 1], GetEntProp(zombie.client, Prop_Data, "m_iHealth"), name);
			}
			else
				FormatEx(info, sizeof info, "(%s)Dead - %s", ZombieName[zombie.class - 1], name);

			panel.DrawText(info);
		}
	}

	delete aClients;

	FormatEx(info, sizeof info, "Refesh [%s]", autoRefresh ? "●" : "○");
	panel.DrawItem(info);

	panel.Send(client, Panel_Handler, 15);
	delete panel;

	delete g_hPanelTimer[client];
	if (autoRefresh)
		g_hPanelTimer[client] = CreateTimer(1.0, tmrPanel, client);
}

int Panel_Handler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 == 4 && !g_hPanelTimer[param1])
				DrawTeamPanel(param1, true);
			else
				delete g_hPanelTimer[param1];
		}

		case MenuAction_Cancel:
			delete g_hPanelTimer[param1];
	}

	return 0;
}

Action tmrPanel(Handle timer, int client) {
	g_hPanelTimer[client] = null;

	DrawTeamPanel(client, true);
	return Plugin_Continue;
}

int GetSurBotsCount() {
	int num;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidSurBot(i))
			num++;
	}
	return num;
}

int GetTempHealth(int client) {
	static ConVar cPainPillsDecay;
	if (!cPainPillsDecay)
		cPainPillsDecay = FindConVar("pain_pills_decay_rate");

	int tempHealth = RoundToFloor(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * cPainPillsDecay.FloatValue);
	return tempHealth < 0 ? 0 : tempHealth;
}

#define GAMEDATA	"system_auto_players"
void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\" (%s)", "1.9");

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	int m_knockdownTimer = FindSendPropInfo("CTerrorPlayer", "m_knockdownTimer");
	m_hWeaponHandle = m_knockdownTimer + 100;
	/*m_hWeaponHandle = hGameData.GetOffset("m_hWeaponHandle");
	if (m_hWeaponHandle == -1)
		SetFailState("Failed to find offset: \"m_hWeaponHandle\" (%s)", "1.9");*/

	m_iRestoreAmmo = m_knockdownTimer + 104;
	/*m_iRestoreAmmo = hGameData.GetOffset("m_iRestoreAmmo");
	if (m_iRestoreAmmo == -1)
		SetFailState("Failed to find offset: \"m_iRestoreAmmo\" (%s)", "1.9");*/

	m_restoreWeaponID = m_knockdownTimer + 108;
	/*m_restoreWeaponID = hGameData.GetOffset("m_restoreWeaponID");
	if (m_restoreWeaponID == -1)
		SetFailState("Failed to find offset: \"m_restoreWeaponID\" (%s)", "1.9");*/

	m_hHiddenWeapon = m_knockdownTimer + 116;
	/*m_hHiddenWeapon = hGameData.GetOffset("m_hHiddenWeapon");
	if (m_hHiddenWeapon == -1)
		SetFailState("Failed to find offset: \"m_hHiddenWeapon\" (%s)", "1.9");*/

	m_isOutOfCheckpoint = FindSendPropInfo("CTerrorPlayer", "m_jumpSupressedUntil") + 4;
	/*m_isOutOfCheckpoint = hGameData.GetOffset("m_isOutOfCheckpoint");
	if (m_isOutOfCheckpoint == -1)
		SetFailState("Failed to find offset: \"m_isOutOfCheckpoint\" (%s)", "1.9");*/

	RestartScenarioTimer = hGameData.GetOffset("RestartScenarioTimer");
	if (RestartScenarioTimer == -1)
		SetFailState("Failed to find offset: \"RestartScenarioTimer\" (%s)", "1.9");

	StartPrepSDKCall(SDKCall_Static);
	Address addr = hGameData.GetMemSig("NextBotCreatePlayerBot<SurvivorBot>");
	if (!addr)
		SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" in \"CDirector::AddSurvivorBot\" (%s)", "1.9");
	if (!hGameData.GetOffset("OS")) {
		Address offset = view_as<Address>(LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32));	// (addr+5) + *(addr+1) = call function addr
		if (!offset)
			SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", "1.9");

		addr += offset + view_as<Address>(5);
	}
	if (!PrepSDKCall_SetAddress(addr))
		SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", "1.9");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	if (!(g_hSDK_NextBotCreatePlayerBot_SurvivorBot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", "1.9");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::RoundRespawn\" (%s)", "1.9");
	if (!(g_hSDK_CTerrorPlayer_RoundRespawn = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::RoundRespawn\" (%s)", "1.9");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSPlayer::State_Transition"))
		SetFailState("Failed to find signature: \"CCSPlayer::State_Transition\" (%s)", "1.9");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CCSPlayer_State_Transition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CCSPlayer::State_Transition\" (%s)", "1.9");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator"))
		SetFailState("Failed to find signature: \"SurvivorBot::SetHumanSpectator\" (%s)", "1.9");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	if (!(g_hSDK_SurvivorBot_SetHumanSpectator = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"SurvivorBot::SetHumanSpectator\" (%s)", "1.9");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::TakeOverBot\" (%s)", "1.9");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CTerrorPlayer_TakeOverBot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::TakeOverBot\" (%s)", "1.9");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\" (%s)", "1.9");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\" (%s)", "1.9");

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"RoundRespawn_Offset\" (%s)", "1.9");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"RoundRespawn_Byte\" (%s)", "1.9");

	g_pStatsCondition = hGameData.GetMemSig("CTerrorPlayer::RoundRespawn");
	if (!g_pStatsCondition)
		SetFailState("Failed to find address: \"CTerrorPlayer::RoundRespawn\" (%s)", "1.9");

	g_pStatsCondition += view_as<Address>(iOffset);
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::RoundRespawn\", byte mis-match @ %d (0x%02X != 0x%02X) (%s)", iOffset, iByteOrigin, iByteMatch, "1.9");
}

// [L4D1 & L4D2] SM Respawn Improved (https://forums.alliedmods.net/showthread.php?t=323220)
void StatsConditionPatch(bool patch) {
	static bool patched;
	if (!patched && patch) {
		patched = true;
		StoreToAddress(g_pStatsCondition, 0xEB, NumberType_Int8);
	}
	else if (patched && !patch) {
		patched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

// Left 4 Dead 2 - CreateSurvivorBot (https://forums.alliedmods.net/showpost.php?p=2729883&postcount=16)
int SpawnSurBot() {
	g_bInSpawnTime = true;
	int bot = SDKCall(g_hSDK_NextBotCreatePlayerBot_SurvivorBot, NULL_STRING);
	if (bot != -1)
		ChangeClientTeam(bot, TEAM_SURVIVOR);

	g_bInSpawnTime = false;
	return bot;
}

void RespawnPlayer(int client) {
	StatsConditionPatch(true);
	g_bInSpawnTime = true;
	SDKCall(g_hSDK_CTerrorPlayer_RoundRespawn, client);
	g_bInSpawnTime = false;
	StatsConditionPatch(false);
}

/**
// https://github.com/bcserv/smlib/blob/2c14acb85314e25007f5a61789833b243e7d0cab/scripting/include/smlib/clients.inc#L203-L215
// Spectator Movement modes
enum Obs_Mode
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};
**/
void SetHumanSpec(int bot, int client) {
	SDKCall(g_hSDK_SurvivorBot_SetHumanSpectator, bot, client);
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
	if (GetEntProp(client, Prop_Send, "m_iObserverMode") == 6)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void TakeOverBot(int client) {
	SDKCall(g_hSDK_CTerrorPlayer_TakeOverBot, client, true);
}

void State_Transition(int client, int state) {
	SDKCall(g_hSDK_CCSPlayer_State_Transition, client, state);
}

// 模拟CDirector::NewPlayerPossessBot(int, int, SurvivorBot *)中的接管方式
bool CheckForTake(int bot, int target) {
	return !GetEntProp(bot, Prop_Send, "m_isIncapacitated") && !GetEntData(target, m_isOutOfCheckpoint);
}

bool OnEndScenario() {
	return view_as<float>(LoadFromAddress(g_pDirector + view_as<Address>(RestartScenarioTimer + 8), NumberType_Int32)) > 0.0;
}

bool PrepRestoreBots() {
	return SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32);
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GoAwayFromKeyboard");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", "1.9");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_GoAwayFromKeyboard_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", "1.9");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_GoAwayFromKeyboard_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", "1.9");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::SurvivorBot::SetHumanSpectator");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::SurvivorBot::SetHumanSpectator\" (%s)", "1.9");

	if (!dDetour.Enable(Hook_Pre, DD_SurvivorBot_SetHumanSpectator_Pre))
		SetFailState("Failed to detour pre: \"DD::SurvivorBot::SetHumanSpectator\" (%s)", "1.9");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CBasePlayer::SetModel");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CBasePlayer::SetModel\" (%s)", "1.9");

	if (!dDetour.Enable(Hook_Post, DD_CBasePlayer_SetModel_Post))
		SetFailState("Failed to detour post: \"DD::CBasePlayer::SetModel\" (%s)", "1.9");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GiveDefaultItems");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::GiveDefaultItems\" (%s)", "1.9");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_GiveDefaultItems_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::GiveDefaultItems\" (%s)", "1.9");
}

// [L4D1 & L4D2]Survivor_AFK_Fix[Left 4 Fix] (https://forums.alliedmods.net/showthread.php?p=2714236)
public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bShouldFixAFK)
		return;

	if (entity < 1 || entity > MaxClients)
		return;

	if (classname[0] != 's' || strcmp(classname[1], "urvivor_bot", false) != 0)
		return;

	g_iSurvivorBot = entity;
}

MRESReturn DD_CTerrorPlayer_GoAwayFromKeyboard_Pre(int pThis, DHookReturn hReturn) {
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GoAwayFromKeyboard_Post(int pThis, DHookReturn hReturn) {
	if (g_bShouldFixAFK && g_iSurvivorBot > 0 && IsFakeClient(g_iSurvivorBot)) {
		g_bShouldIgnore = true;
		SetHumanSpec(g_iSurvivorBot, pThis);
		WriteTakeoverPanel(pThis, g_iSurvivorBot);
		g_bShouldIgnore = false;
	}

	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

MRESReturn DD_SurvivorBot_SetHumanSpectator_Pre(int pThis, DHookParam hParams) {
	if (!g_bShouldFixAFK)
		return MRES_Ignored;

	if (g_bShouldIgnore)
		return MRES_Ignored;

	if (g_iSurvivorBot < 1)
		return MRES_Ignored;

	return MRES_Supercede;
}

// [L4D(2)] Survivor Identity Fix for 5+ Survivors (https://forums.alliedmods.net/showpost.php?p=2718792&postcount=36)
MRESReturn DD_CBasePlayer_SetModel_Post(int pThis, DHookParam hParams) {
	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis) || IsFakeClient(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != TEAM_SURVIVOR) {
		g_ePlayer[pThis].Model[0] = '\0';
		return MRES_Ignored;
	}

	char model[128];
	hParams.GetString(1, model, sizeof model);
	if (StrContains(model, "models/survivors/survivor_", false) == 0)
		strcopy(g_ePlayer[pThis].Model, sizeof Player::Model, model);

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GiveDefaultItems_Pre(int pThis) {
	if (!g_bGiveType)
		return MRES_Ignored;

	if (g_bShouldFixAFK || g_bGiveTime && !g_bInSpawnTime)
		return MRES_Ignored;

	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != TEAM_SURVIVOR || !IsPlayerAlive(pThis) || ShouldIgnore(pThis))
		return MRES_Ignored;

	GiveDefaultItems(pThis);
	ClearRestoreWeapons(pThis);
	return MRES_Supercede;
}

void WriteTakeoverPanel(int client, int bot) {
	char buf[2];
	IntToString(GetCharacter(bot)/*GetEntProp(bot, Prop_Send, "m_survivorCharacter")*/, buf, sizeof buf);
	BfWrite bf = view_as<BfWrite>(StartMessageOne("VGUIMenu", client, USERMSG_RELIABLE));
	bf.WriteString("takeover_survivor_bar");
	bf.WriteByte(true);
	bf.WriteByte(1);
	bf.WriteString("character");
	bf.WriteString(buf);
	EndMessage();
}

// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery/blob/ac3f62eebe95d80fcf610fb6c7c1ed56bf4b31d2/%5BL4D2%5DAdrenaline_Recovery.sp#L96-L177)
int GetCharacter(int client) {
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b'://nick
			return 0;
		case 'd'://rochelle
			return 1;
		case 'c'://coach
			return 2;
		case 'h'://ellis
			return 3;
		case 'v'://bill
			return 4;
		case 'n'://zoey
			return 5;
		case 'e'://francis
			return 6;
		case 'a'://louis
			return 7;
		default:
			return GetEntProp(client, Prop_Send, "m_survivorCharacter");
	}
}

bool ShouldIgnore(int client) {
	if (IsFakeClient(client))
		return !!GetIdlePlayerOfBot(client);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != TEAM_SPECTATOR)
			continue;

		if (GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTeam", _, i) == TEAM_SURVIVOR && GetIdlePlayerOfBot(i) == client)
			return true;
	}

	return false;
}

void ClearRestoreWeapons(int client) {
	SetEntData(client, m_hWeaponHandle, 0, _, true);
	SetEntData(client, m_iRestoreAmmo, -1, _, true);
	SetEntData(client, m_restoreWeaponID, 0, _, true);
}

void GiveDefaultItems(int client) {
	RemoveAllWeapons(client);
	for (int i = 4; i >= 2; i--) {
		if (!g_eWeapon[i].Count)
			continue;

		GivePlayerItem(client, g_sWeaponName[i][g_eWeapon[i].Allowed[Math_GetRandomInt(0, g_eWeapon[i].Count - 1)]]);
	}

	GiveSecondary(client);
	switch (g_cGiveType.IntValue) {
		case 1:
			GivePresetPrimary(client);

		case 2:
			GiveAveragePrimary(client);
	}
}

void GiveSecondary(int client) {
	if (g_eWeapon[1].Count) {
		int val = g_eWeapon[1].Allowed[Math_GetRandomInt(0, g_eWeapon[1].Count - 1)];
		if (val > 2)
			GiveMelee(client, g_sWeaponName[1][val]);
		else
			GivePlayerItem(client, g_sWeaponName[1][val]);
	}
}

void GivePresetPrimary(int client) {
	if (g_eWeapon[0].Count)
		GivePlayerItem(client, g_sWeaponName[0][g_eWeapon[0].Allowed[Math_GetRandomInt(0, g_eWeapon[0].Count - 1)]]);
}

bool IsWeaponTier1(int weapon) {
	char cls[32];
	GetEntityClassname(weapon, cls, sizeof cls);
	for (int i; i < 5; i++) {
		if (strcmp(cls, g_sWeaponName[0][i], false) == 0)
			return true;
	}
	return false;
}

void GiveAveragePrimary(int client) {
	int i = 1, tier, total, weapon;
	if (g_bRoundStart) {
		for (; i <= MaxClients; i++) {
			if (i == client || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
				continue;

			total += 1;
			weapon = GetPlayerWeaponSlot(i, 0);
			if (weapon <= MaxClients || !IsValidEntity(weapon))
				continue;

			tier += IsWeaponTier1(weapon) ? 1 : 2;
		}
	}

	switch (total > 0 ? RoundToNearest(float(tier) / float(total)) : 0) {
		case 1:
			GivePlayerItem(client, g_sWeaponName[0][Math_GetRandomInt(0, 4)]);

		case 2:
			GivePlayerItem(client, g_sWeaponName[0][Math_GetRandomInt(5, 14)]);
	}
}

void RemoveAllWeapons(int client) {
	int weapon;
	for (int i; i < MAX_SLOT; i++) {
		if ((weapon = GetPlayerWeaponSlot(client, i)) <= MaxClients)
			continue;

		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}

	weapon = GetEntDataEnt2(client, m_hHiddenWeapon);
	SetEntDataEnt2(client, m_hHiddenWeapon, -1, true);
	if (weapon > MaxClients && IsValidEntity(weapon) && GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity") == client) {
		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}
}

// https://github.com/bcserv/smlib/blob/2c14acb85314e25007f5a61789833b243e7d0cab/scripting/include/smlib/math.inc#L144-L163
#define SIZE_OF_INT	2147483647 // without 0
int Math_GetRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}