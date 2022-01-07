#define PLUGIN_NAME "Balance Mod Mantreads"
#define PLUGIN_DESCRIPTION "Removes fall damage without nerfing stomp"
#define PLUGIN_AUTHOR "Fragancia"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "Balancemod.tf"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf_ontakedamage>
#include <tf2wearables>
#include <tf2attributes>

#pragma newdecls required
#pragma semicolon 1

enum //Convar names
{
	CV_bDebugMode,
	CV_flRocketJumpBoost,
	CV_flFallDmgReduction,
	CV_PluginVersion
}

/* Enum Structs */


/* Global Variables */
int g_iLastFallDamage[MAXPLAYERS+1];
/* Global Handles */

//Handle g_hGameConf;

/* Dhooks */

/* Convar Handles */

ConVar g_cvCvarList[CV_PluginVersion+1];

/* Convar related global variables */

float g_cv_flRocketJumpBoost;
float g_cv_flFallDmgReduction;
bool g_cv_bDebugMode;

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};
public void OnPluginStart()
{
	/* DHooks Setup */
	
	/* Convars */
	
	g_cvCvarList[CV_PluginVersion] = CreateConVar("bm_mantreads_version", PLUGIN_VERSION, "Plugin Version.", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT);
	g_cvCvarList[CV_flRocketJumpBoost] = CreateConVar("bm_mantreads_rj_boost", "1.8", "Rocket jump boost for mantread users", FCVAR_NOTIFY, true, 0.0);
	g_cvCvarList[CV_flFallDmgReduction] = CreateConVar("bm_mantreads_fall_damage_reduction", "1.0", "Reduces fall damage", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvCvarList[CV_bDebugMode] = CreateConVar("bm_mantreads_debug", "0", "Enable Debugging", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	/* Convar global variables init */
	
	g_cv_bDebugMode = GetConVarBool(g_cvCvarList[CV_bDebugMode]);
	g_cv_flRocketJumpBoost = g_cvCvarList[CV_flRocketJumpBoost].FloatValue;
	g_cv_flFallDmgReduction = g_cvCvarList[CV_flFallDmgReduction].FloatValue;
	
	/* Convar Change Hooks */
	
	g_cvCvarList[CV_bDebugMode].AddChangeHook(CvarChangeHook);
	g_cvCvarList[CV_flRocketJumpBoost].AddChangeHook(CvarChangeHook);
	g_cvCvarList[CV_flFallDmgReduction].AddChangeHook(CvarChangeHook);
	
	/* Event Hooks */
	
	HookEvent("player_spawn", 	Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("post_inventory_application", 	Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", 	Event_PlayerDeath, EventHookMode_Pre);

	/* Commands */
	//RegAdminCmd("sm_ts", Command_TS, ADMFLAG_SLAY, "");
	
	/* Other */
	AddAllRJBoost();
}
public void OnPluginEnd()
{
	RemoveAllRJBoost();
}
/* Publics */
public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
		int &damagetype, int &weapon, float damageForce[3], float damagePosition[3],
		int damagecustom, CritType &critType)
{
	if(g_cv_bDebugMode) PrintToChatAll("flDamage: %f\nattacker: %i, victim: %i, inflictor: %i\nweapon: %i, flags: %i, customflags: %i", damage, attacker, victim, inflictor, weapon, damagetype, damagecustom);
	
	if(TF2_GetPlayerClass(victim) == TFClass_Soldier)
	{
		if(damagetype & DMG_FALL) //!damagecustom & TF_CUSTOM_BOOTS_STOMP)
		{
			int iWearable = TF2_GetPlayerLoadoutSlot(victim, TF2LoadoutSlot_Secondary);
			if(g_cv_bDebugMode) PrintToChatAll("Wearable: %i", iWearable);
			
			if(attacker == 0 && IsMantreads(iWearable))
			{
				int iDamage;
				int iHealth = GetEntProp(victim, Prop_Send, "m_iHealth");
				
				if(g_cv_flFallDmgReduction >= 0.0)
				{
					iDamage = RoundToNearest((damage * g_cv_flFallDmgReduction));
					SetEntityHealth(victim, (iHealth + iDamage));
				}
				else if(g_cv_flFallDmgReduction == 1.0)
				{
					iDamage = RoundToNearest(damage);
					SetEntityHealth(victim, (iHealth + iDamage));
				}
				
				g_iLastFallDamage[victim] = iDamage;
				
				return Plugin_Continue;
			}
		}
	}
	if(damagetype & DMG_FALL && damagecustom & TF_CUSTOM_BOOTS_STOMP)
	{
		if(IsMantreads(weapon))
		{
			int iHealth = GetEntProp(attacker, Prop_Send, "m_iHealth");
			int iDamage = g_iLastFallDamage[attacker];
			SetEntityHealth(attacker, (iHealth - iDamage));
		}
	}
	return Plugin_Continue;
}
public Action Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(IsValidClient(client) && TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		int iWearable = TF2_GetPlayerLoadoutSlot(client, TF2LoadoutSlot_Secondary);
		int iRL = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		
		if(IsMantreads(iWearable))
		{
			RemoveRJBoostAttribute(iRL);
		}
	}
}
public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsValidClient(client) && TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		int iWearable = TF2_GetPlayerLoadoutSlot(client, TF2LoadoutSlot_Secondary);
		int iRL = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);

		if(IsMantreads(iWearable))
		{
			AddRJBoostAttribute(iRL, g_cv_flRocketJumpBoost);
		}
		else
		{
			RemoveRJBoostAttribute(iRL);
		}
	}
}
public void CvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
	if(convar == g_cvCvarList[CV_bDebugMode]) g_cv_bDebugMode = view_as<bool>(StringToInt(sNewValue));
	if(convar == g_cvCvarList[CV_flRocketJumpBoost])
	{
		g_cv_flRocketJumpBoost = StringToFloat(sNewValue);
		UpdateAllRJBoost();
	}
	if(convar == g_cvCvarList[CV_flFallDmgReduction]) g_cv_flFallDmgReduction = StringToFloat(sNewValue);
}
//public Action Command_TS(int client, int args)
//{
//	if(args < 1)
//	{
//		int iRL = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
//		RemoveRJBoostAttribute(iRL);
//	}
//}
/* Plugin Exclusive Functions */
void AddAllRJBoost()
{
	for(int client = 1; client < MaxClients; client++)
	{
		if(IsValidClient(client) && TF2_GetPlayerClass(client) == TFClass_Soldier)
		{
			int iWearable = TF2_GetPlayerLoadoutSlot(client, TF2LoadoutSlot_Secondary);
			int iRL = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			
			if(IsMantreads(iWearable))
			{
				AddRJBoostAttribute(iRL, g_cv_flRocketJumpBoost);
			}
		}
	}
}
void UpdateAllRJBoost()
{
	for(int client = 1; client < MaxClients; client++)
	{
		if(IsValidClient(client) && TF2_GetPlayerClass(client) == TFClass_Soldier)
		{
			int iWearable = TF2_GetPlayerLoadoutSlot(client, TF2LoadoutSlot_Secondary);
			int iRL = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			
			if(IsMantreads(iWearable))
			{
				AddRJBoostAttribute(iRL, g_cv_flRocketJumpBoost);
			}
		}
	}
}
void RemoveAllRJBoost()
{
	for(int client = 1; client < MaxClients; client++)
	{
		if(IsValidClient(client) && TF2_GetPlayerClass(client) == TFClass_Soldier)
		{
			int iWearable = TF2_GetPlayerLoadoutSlot(client, TF2LoadoutSlot_Secondary);
			int iRL = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			
			if(IsMantreads(iWearable))
			{
				RemoveRJBoostAttribute(iRL);
			}
		}
	}
}
void AddRJBoostAttribute(int weapon, float value)
{
	if(g_cv_bDebugMode)PrintToChatAll("Applied boost on a player: %f", g_cv_flRocketJumpBoost);
	TF2Attrib_SetByName(weapon, "self dmg push force increased", value);
}
void RemoveRJBoostAttribute(int weapon)
{
	if(g_cv_bDebugMode)PrintToChatAll("Removed extra jump boost on a player");
	TF2Attrib_RemoveByName(weapon, "self dmg push force increased");
}
bool IsMantreads(int weapon)
{
	if(weapon == -1 && weapon <= MaxClients) return false;
	
	switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
	{
		//If Mantreads gets skins in future with different indices, add them here
		case 444: //Mantreads
		{
			return true;
		}
	}
	return false;
}
/* Stocks */

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}
